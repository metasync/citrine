# frozen-string-literal: true

module Citrine
  module Configurator
    module Autoloader
      module Task
        class Base
          def self.create(scheme, **opts)
            if opts[:name].nil?
              Bulk.new(scheme, opts)
            else
              Simple.new(scheme, opts)
            end
          end

          include Utils::BaseObject
          include Utils::Common

          attr_reader :scheme
          attr_reader :autoloader
          attr_reader :signal
          attr_reader :data

          def initialize(scheme, autoloader:, **opts)
            @scheme_name = scheme.to_s
            @scheme_tag = ""
            @scheme = @scheme_name
            @scheme_keys = [:type]
            @autoloader = autoloader
            @signal = "#{scheme}_loaded".to_sym
            @data = {}
            opts[:type] ||= @scheme_name.singularize
            super(opts)
          end

          def load_scheme
            load_scheme!.tap { |result| process_result(result) if result.ok? }
          end

          def config_data
            raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
          end

          protected

          attr_reader :scheme_name
          attr_reader :scheme_tag
          attr_reader :scheme_keys
          attr_reader :scheme_params

          def post_init
            set_scheme_params
          end

          def set_scheme_params
            @scheme_params = options.slice(*scheme_keys)
          end

          def load_scheme!
            raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
          end

          def process_result(result)
            raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
          end

          def deserialize_scheme_config(config)
            config[:data] = Kernel.const_get(config[:serializer].upcase)
              .load(config[:data])
          end
        end
      end
    end
  end
end
