# frozen-string-literal: true

module Citrine
  module Configurator
    module Autoloader
      class Base < Citrine::Integrator::Delegator
        class << self
          def registry_name
            @registry_name ||= "configurator"
          end
        end

        DEFAULT_ROOT_PATH = "/api/scheme"
        DEFAULT_AUTOLOAD_INTERVAL = 300
        DEFAULT_RETRY_INTERVAL = 15

        attr_reader :tasks

        def kick_start
          run_bootstrap
          on_event(:launch)
          schedule_next_autoload
        end

        protected

        def set_default_options
          @default_options ||= super.merge!(
            root_path: DEFAULT_ROOT_PATH,
            autoload_interval: DEFAULT_AUTOLOAD_INTERVAL,
            retry_interval: DEFAULT_RETRY_INTERVAL
          )
        end

        def on_init
          super
          options[:abort_on_error] = false
        end

        def set_default_values
          super
          set_service_options
          set_default_event_callbacks
        end

        def set_service_options
          options[:service][:request].merge!(options.slice(:base_uri, :root_path))
        end

        def set_default_event_callbacks
          @event_callbacks = {
            launch: options[:on_launch] || {},
            update: options[:on_update] || {}
          }
        end

        def validate
          super
          if options[:base_uri].nil?
            raise ArgumentError, "base_uri is MUST be specified."
          end
        end

        def post_init
          super
          create_autoload_tasks
          kick_start
        end

        def create_autoload_tasks
          options[:autoload].each_with_object(@tasks = {}) do |(task, opts), tasks|
            tasks[task] = Task::Base.create(task, (opts || {}).merge(autoloader: self))
          end
        end

        def run_bootstrap
          tasks.each_pair do |name, task|
            unless run_autoload_task(task)
              quit "Error!! Failed to retrieve scheme #{name}."
            end
          end
        end

        def schedule_next_autoload
          after(options[:autoload_interval]) do
            on_event(:update) if run_autoload_once
            schedule_next_autoload
          end
        end

        def run_autoload_once
          tasks.inject(false) do |updated, (_, task)|
            run_autoload_task(task) || updated
          end
        end

        def run_autoload_task(task)
          async.run_autoload_task!(task)
          wait(task.signal)
        end

        def run_autoload_task!(task)
          result = task.load_scheme
          if result.ok?
            info "Successfully retrieved scheme #{task.scheme}"
            signal task.signal, true
          elsif result.error?
            error "Failed to retrieve scheme #{task.scheme}: #{result.message} (#{result.code})"
            after(options[:retry_interval]) { run_autoload_task!(task) }
          else
            info "#{result.message} (#{result.code})"
            signal task.signal, false
          end
        end

        def on_event(event)
          compose_service_config.tap do |service_config|
            @event_callbacks[event].each_pair do |actor_name, operation|
              actor(actor_name).send(operation, service_config)
            end
          end
        end

        def compose_service_config
          tasks.each_with_object(schemes = {}) do |(name, task), schemes|
            unless (name == :service) || task.data.empty?
              schemes[name] = task.config_data
            end
          end
          (tasks[:service]&.config_data || {}).tap do |service_config|
            service_config[:schemes] ||= {}
            service_config[:schemes].merge!(schemes)
          end
        end
      end
    end
  end
end
