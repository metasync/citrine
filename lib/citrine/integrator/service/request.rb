# frozen-string-literal: true

module Citrine
  module Integrator
    module Service
      class Request
        class UndefinedPathParam < Error
          def initialize(name)
            super("Path parameter :#{name} is NOT defined.")
          end
        end

        DEFAULT_TIMEOUT = 5 # seconds
        DEFAULT_SERIALIZATIONS = {
          get: "params", head: "params", delete: "params",
          post: "json", put: "json", patch: "json"
        }

        attr_reader :default_spec
        attr_reader :spec
        attr_reader :method
        attr_reader :base_uri
        attr_reader :path_pattern
        attr_reader :path_params
        attr_reader :path
        attr_reader :client
        attr_reader :headers
        attr_reader :params
        attr_reader :options
        attr_reader :query
        attr_reader :body
        attr_reader :raw_body
        attr_reader :error

        def initialize(spec, client:, headers: {}, raw_body: nil, **params)
          @error = nil
          @spec = spec
          @method = spec[:method]
          @base_uri = spec[:base_uri]
          @path_pattern = compose_path_pattern
          @path_params = parse_path_params
          @client = client
          @headers = headers
          @raw_body = raw_body
          @params = params
          set_default_spec
          on_init
          set_default_values
          validate
          @params = convert_params
          set_options
          @path = build_path
          @query, @body = build_request
        end

        alias_method :query_string, :query

        def has_headers? = !@headers.nil? && !@headers.empty?

        def has_params? = !@params.nil? && !@params.empty?

        def error? = !@error.nil?

        def to_h
          {method: method, base_uri: base_uri, path: path,
           headers: headers, params: params, query: query, body: body}
        end
        alias_method :to_hash, :to_h

        protected

        def set_default_spec
          @default_spec ||= {timeout: DEFAULT_TIMEOUT,
                             serialization: DEFAULT_SERIALIZATIONS[method.to_sym]}
        end

        def set_default_values
          @spec = default_spec.merge(@spec)
        end

        def on_init
        end

        def validate
        end

        def convert_params
          result =
            Schema.parse(spec[:parameters], params, spec.slice(*Schema.general_options))
          @error = result[:error]
          result[:data]
        end

        def set_options
          @options = raw_body.nil? ? default_params_options : default_body_options
        end

        def default_params_options
          {spec[:serialization].to_sym => params}
        end

        def default_body_options
          {body: raw_body.to_s}
        end

        def compose_path_pattern
          File.join(spec[:root_path], spec[:path])
        end

        def parse_path_params
          path_pattern.scan(/:(\w+)/).flatten
        end

        def build_path
          path_params.each_with_object(path_pattern.clone) do |param, path|
            raise UndefinedPathParam.new(param) if params[param.to_sym].nil?
            path.sub!(/:#{param}/, params[param.to_sym].to_s)
          end
        end

        def build_request
          @client.build_request(self).values_at(:query, :body)
        end
      end
    end
  end
end
