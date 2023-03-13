# frozen-string-literal: true

require "pathname"

module Citrine
  class Manager < Actor
    class << self
      def supervisor
        @supervisor ||= Celluloid::Supervision::Container.run!
      end

      def launch(**options)
        super(supervisor, **options)
      end
    end

    attr_reader :work_dir
    attr_reader :config_dir
    attr_reader :config_files
    attr_reader :config

    def supervisor
      self.class.supervisor
    end

    def start_setup
      if config.has_repositories?
        if options[:system_migration_dir].nil? ||
            options[:system_migration_table].nil?
          quit "Setup failed to start: system migration path or table is NOT specified."
        else
          launch_migrator
          launch_repositories
          actor(:migrator).start_migration(
            options[:migration_command],
            migration_dir: options[:system_migration_dir],
            migration_table: options[:system_schema].nil? ?
              options[:system_migration_table] : 
              Sequel.qualify(options[:system_schema], options[:system_migration_table])
          )
        end
      else
        quit "Setup failed to start: repository configuration is NOT specified."
      end
    end

    def start_migration
      if config.has_repositories?
        launch_migrator
        launch_repositories
        actor(:migrator).start_migration(options[:migration_command])
      else
        quit "Migration failed to start: repository configuration is NOT specified."
      end
    end

    def start_service
      if config.has_gateway?
        launch_repositories if config.has_repositories?
        launch_interactors if config.has_interactors?
        launch_wardens if config.has_wardens?
        launch_integrators if config.has_integrators?
        launch_gateway
        run_initializers if config.has_initializers?
      else
        quit "Service failed to start: gateway configuration is NOT specified."
      end
    end

    def start_jobs
      if config.has_jobs?
        launch_repositories if config.has_repositories?
        launch_interactors if config.has_interactors?
        launch_wardens if config.has_wardens?
        launch_integrators if config.has_integrators?
        launch_gateway if config.has_gateway?
        run_initializers if config.has_initializers?
        launch_runner
      else
        quit "Jobs runner failed to start: jobs configuration is NOT specified."
      end
    end

    protected

    def on_init
      configure_dirs
      load_configuration
      load_logger
      @auto_run = "start_#{options[:operation] || :service}"
    end

    def configure_dirs
      @config_files = options[:config_files].map do |config_file|
        Pathname.new(config_file)
      end
      @config_dir = @config_files.last.dirname
      @work_dir = locate_work_dir(@config_dir)
    end

    def locate_work_dir(config_dir)
      dir = Pathname.new(config_dir).dirname
      dir = dir.dirname while dir.to_s =~ /config/
      dir
    end

    def load_configuration
      load_configuration!
      load_configuration_with_configurator if config.has_configurator?
    end

    def load_configuration!
      @config = create_configuration.new(config_files)
    end

    def create_configuration
      get_or_set_constant("Configuration", namespace: namespace_module,
        base: Citrine::Configuration)
    end

    def load_configuration_with_configurator
      config_files.unshift Pathname.new(configurator_config_file)
      load_configuration!
    end

    def configurator_config_file
      @configurator_config_file ||=
        File.expand_path("../../../config/configurator.yml", __FILE__)
    end

    def load_logger
      Actor.logger.level =
        Logger.const_get((config.logger[:level] || "info").to_s.upcase)
    end

    def post_init
      async.start_operation
    end

    def start_operation
      launch_configurator if config.has_configurator?
      send(@auto_run)
    end

    def launch_configurator
      create_config_autoloader(create_configurator_module)
        .launch(supervisor, config.configurator)
    end

    def create_configurator_module
      get_or_set_constant("Configurator", namespace: namespace_module, base: Module)
    end

    def create_config_autoloader(configurator_module)
      get_or_set_constant("Autoloader", namespace: configurator_module,
        base: Citrine::Configurator::Autoloader::Base)
    end

    def launch_migrator
      require_relative "migrator"
      create_migrator.launch(supervisor)
    end

    def create_migrator
      get_or_set_constant("Migrator", namespace: namespace_module,
        base: Citrine::Migrator)
    end

    def launch_repositories
      launch_actors(:repositories, base: repository_base, work_dir: work_dir)
    end

    def repository_base
      get_or_set_constant("Repository", namespace: namespace_module,
        base: Citrine::Repository[:sql])
    end

    def launch_integrators
      launch_actors(:integrators,
        base: ->(config) {
          config[:service] ? Citrine::Integrator::Delegator :
                             Citrine::Integrator::Proxy
        })
    end

    def launch_wardens
      launch_actors(:wardens, base: Citrine::Warden::Base)
    end

    def launch_interactors
      launch_actors(:interactors, base: Citrine::Interactor::Base)
    end

    def launch_actors(actors, base: nil, **opts)
      actors_module = get_or_set_constant(
        actors.to_s.camelize, namespace: namespace_module, base: Module
      )
      config.send(actors).each_key do |actor|
        next if actor == :general
        actor_class = actor.to_s.classify
        actor_config = config.send(actor) || {}
        base_class = base.respond_to?(:call) ? base.call(actor_config) : base
        if base_class.nil?
          actors_module.const_get(actor_class)
        else
          get_or_set_constant(actor_class, namespace: actors_module, base: base_class)
        end.launch(supervisor, **actor_config.merge!(opts))
      end
    end

    def launch_gateway
      gateway_module = create_gateway_module
      create_gateway_server(gateway_module).launch(
        supervisor,
        router: create_gateway_router(gateway_module),
        **config.gateway_server
      )
    end

    def create_gateway_module
      get_or_set_constant("Gateway", namespace: namespace_module, base: Module)
    end

    def create_gateway_router(gateway_module)
      get_or_set_constant(
        "Router", namespace: gateway_module, base: Citrine::Gateway::Router
      ).tap do |gateway_router|
        gateway_router.bootstrap(config.gateway_router)
      end
    end

    def create_gateway_server(gateway_module)
      get_or_set_constant("Server", namespace: gateway_module, base: Citrine::Gateway::Server)
    end

    def launch_runner
      create_runner.launch(supervisor, pool_size: 1,
        job_filter: options[:job_filter],
        jobs: config.jobs)
    end

    def create_runner
      get_or_set_constant("Runner", namespace: namespace_module,
        base: Citrine::Runner::Base)
    end

    def run_initializers
      config.initializers.each_pair do |name, operation|
        actor(name).send(operation)
      end
    end

    def reload_service(new_config = nil)
      reload_configuration(new_config) unless new_config.nil?
      reload_logger
      reload_actors(:repositories, work_dir: work_dir) if config.has_repositories?
      reload_actors(:interactors) if config.has_interactors?
      reload_actors(:wardens) if config.has_wardens?
      reload_actors(:integrators) if config.has_integrators?
      if options[:operation] == :jobs
        reload_actor(:runner, pool_size: 1,
          job_filter: options[:job_filter],
          jobs: config.jobs)
      end
    end

    def reload_configuration(new_config)
      config.merge(new_config)
    end

    alias_method :reload_logger, :load_logger

    def reload_actors(actors, **opts)
      config.send(actors).each_key do |actor|
        if (actor != :general) && actor_registered?(actor)
          reload_actor(actor, config.send(actor).merge!(opts))
        end
      end
    end

    def reload_actor(actor, pool_size: nil, **opts)
      actor_to_reload = self.actor(actor)
      if actor_to_reload.recycle(args: [opts])
        info "Recycled #{actor} successfully"
      else
        info "Skipped recycling #{actor} due to unchanged configurations"
      end
      unless pool_size.nil?
        current_size, new_size = actor_to_reload.size, pool_size.to_i
        if current_size == new_size
          info "Skipped resizing #{actor} due to unchanged size (#{new_size})"
        else
          actor_to_reload.size = new_size
          info "Resized #{actor} from #{current_size} to #{new_size}"
        end
      end
    end
  end
end
