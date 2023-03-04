# frozen-string-literal: true

module Citrine
  module Configurator
    module Autoloader
      module Task
        class Simple < Base
          def config_data
            Utils.deep_clone(data[:config][:data])
              .merge!(__scheme__: data[:name],
                __config_id__: data[:config][:id])
          end

          protected

          def on_init
            super
            @scheme = @scheme_name = "#{scheme_name}:#{options[:name]}"
            @scheme_keys << :name
          end

          def validate
            super
            if options[:name].nil?
              raise ArgumentError, "Scheme name MUST be specified."
            end
          end

          def load_scheme!
            autoloader.retrieve_scheme(scheme_params)
          end

          def process_result(result)
            @data = Utils.deep_clone(result.data)
            deserialize_scheme_config(data[:config])
            scheme_params[:config_id] = data[:config][:id]
            @scheme_tag = "config_id: #{data[:config][:id]}"
            @scheme = "#{scheme_name} (#{scheme_tag})"
          end
        end
      end
    end
  end
end
