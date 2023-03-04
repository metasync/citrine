# frozen-string-literal: true

module Citrine
  module Repository
    class Base < Actor
      class << self
        def inherited(subclass)
          super
          # Ensure models from the base class
          # got inherited to its subclasses
          models.each_pair do |name, init_blk|
            subclass.model(name, &init_blk.clone)
          end
        end

        def general_options
          [:pool_size, :migration_dir, :migration_table,
            :validation_interval, :reconnect_interval, :enable_sql_log]
        end

        def models = @models ||= {}

        def model(name, &init_blk)
          models[name] = init_blk || proc {}
          define_default_model_commands(name)
          models[name]
        end

        def define_default_model_commands(model)
          class_command "new_#{model}", delegate: :new, to: model
          class_command "create_#{model}", delegate: :create, to: model
          class_command "find_#{model.to_s.pluralize}", delegate: :where_all, to: model
          class_command "filter_#{model.to_s.pluralize}", delegate: :where_all, to: model
          class_command "find_#{model}", delegate: :find, to: model
          instance_command "save_#{model}", delegate: :save
          instance_command "save_#{model}_changes", delegate: :save_changes
        end

        def class_command(cmd, to:, delegate: cmd)
          define_method(cmd) do |*args|
            wait_for_connection
            to_struct(models[to].send(delegate, *args))
          rescue => e
            handle_exception(e)
          end
        end

        def instance_command(cmd, delegate: cmd)
          define_method(cmd) do |struct, *args|
            wait_for_connection
            to_struct(models[struct.model].from_struct(struct).send(delegate, *args))
          rescue => e
            handle_exception(e)
          end
        end

        def command(cmd, to: nil, delegate: cmd)
          if to.nil?
            instance_command(cmd, delegate: delegate)
          else
            class_command(cmd, to: to, delegate: delegate)
          end
        end

        def to_struct(obj)
          if obj.is_a?(Array)
            obj.map { |o| to_struct(o) }
          elsif obj.respond_to?(:to_struct)
            obj.to_struct.tap { |s| s.repository = registry_name }
          else
            obj
          end
        end
      end

      attr_reader :models

      finalizer :disconnect

      def connected? = @connected

      def disconnected? = !@connected

      def has_models? = !self.class.models.empty?

      def migrator_launched? = actor_launched?(:migrator)

      def run_sql(sql, opts = {})
        wait_for_connection
        _run_sql!(sql, **opts)
      rescue => e
        handle_exception(e)
      end

      def run_migration(opts = {})
        wait_for_connection
        _run_migration!(**opts)
      rescue => e
        handle_exception(e)
      end

      def table_exists?(table)
        wait_for_connection
        _table_exists?(table)
      rescue => e
        handle_exception(e)
      end

      def schema(table)
        require "ostruct"
        if table_exists?(table)
          Hash[*_schema(table).flatten].each_with_object({}) do |(col, attrs), schema|
            schema[col] = OpenStruct.new(attrs).tap { |c| c.name = col }
          end
        else
          {}
        end
      rescue => e
        handle_exception(e)
      end

      def foreign_keys(table)
        if table_exists?(table)
          _foreign_keys(table).each_with_object({}) do |fk, fks|
            fks[fk[:name]] = OpenStruct.new(fk)
          end
        else
          {}
        end
      rescue => e
        handle_exception(e)
      end

      def to_struct(obj) = self.class.to_struct(obj)

      protected

      def on_init
        @connected = false
        @models = {}
      end

      def set_default_options
        @default_options ||=
          super.merge!(validation_interval: DEFAULT_VALIDATION_INTERVAL,
            reconnect_interval: DEFAULT_RECONNECT_INTERVAL,
            enable_sql_log: false)
      end

      def post_init
        setup_validator
        setup_connector
        @connector.resume unless connect
      end

      def setup_connector
        @connector = every(options[:reconnect_interval]) { connect }
        @connector.pause
      end

      def setup_validator
        @validator = every(options[:validation_interval]) { check }
        @validator.pause
      end

      def connect
        info "Connecting to #{options[:database]}"
        create_connection
        @connected = true
        @connector.pause
        @validator.resume
        create_models if has_models? && !migrator_launched?
        signal :connected
        info "Connected to #{options[:database]}"
        true
      rescue *connection_errors => e
        error "Failed to connect to #{options[:database]}: #{e}"
        false
      end

      def disconnect
        return if disconnected?
        info "Disconnecting from #{options[:database]}"
        destroy_connection
        info "Disconnected from #{options[:database]}"
      ensure
        @connected = false
        @connector.pause
        @validator.pause
      end

      def check
        unless valid_connection?
          @connected = false
          @validator.pause
          @connector.resume
        end
      end

      def valid_connection?
        connected? && check_connection
      end

      def wait_for_connection
        wait :connected if disconnected?
      end

      %w[create_connection connection_errors
        destroy_connection check_connection create_models].each do |name|
        define_method(name) do
          raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
        end
      end

      %w[_run_sql! _run_migration!].each do |name|
        define_method(name) do |action:, **opts|
          raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
        end
      end

      %w[_table_exist? _schema].each do |name|
        define_method(name) do |table|
          raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
        end
      end

      def handle_exception(exception)
        async.check
        abort exception
      end
    end
  end
end
