# frozen-string-literal: true

module Citrine
  module Configurator
    module Autoloader
      module Task
        class Bulk < Base
          def config_data
            data.each_with_object({}) do |(name, scheme), config|
              config[transform_name(name, scheme[:config][:data])] =
                Utils.deep_clone(scheme[:config][:data])
                  .merge!(__scheme__: scheme[:name],
                    __config_id__: scheme[:config][:id])
            end
          end

          protected

          def transform_name(name, config_data)
            trans_method = options[:transform_name] || options[:transform_key]
            case trans_method
            when String
              name.respond_to?(trans_method) ? name.send(trans_method) : name
            when Hash
              config_data[trans_method[:bind_to].to_sym]
            else
              name
            end
          end

          def load_scheme!
            autoloader.refresh_schemes(scheme_params)
          end

          def process_result(result)
            Utils.deep_clone(result.data[:update]).each do |scheme|
              deserialize_scheme_config(scheme[:config])
              @data[scheme[:name]] = scheme
            end
            result.data[:remove].each { |name| @data.delete(name) }
            scheme_params[:base] =
              @data.map do |name, scheme|
                {name: name, config_id: scheme[:config][:id]}
              end
            @scheme_tag = "total: #{scheme_params[:base].size}; " \
              "updated: #{result.data[:update].size}; " \
              "removed: #{result.data[:remove].size}"
            @scheme = "#{@scheme_name} (#{scheme_tag})"
          end
        end
      end
    end
  end
end
