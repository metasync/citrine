# frozen-string-literal: true

module Citrine
  module Integrator
    module Service
      class Base
        using CoreRefinements
        include Utils::BaseObject
        include Utils::Namespace

        def disconnect = destroy_clients

        protected

        attr_reader :clients

        def on_init
          @clients = {}
        end

        def set_default_values
          super
          @options[:apis] ||= {}
          @options[:conversion] ||= {}
        end

        def post_init
          create_apis
        end

        def client_class(adapter)
          Client[adapter || :httprb]
        end

        def destroy_clients
          @clients.each_value { |c| c.destroy }
        end

        def create_apis
          options[:apis].each_pair { |name, spec| create_api(name, api_spec(spec)) }
        end

        def create_api(name, spec)
          client = create_client(spec[:adapter], spec[:request][:base_uri])
          define_singleton_method(name) { |**params| request(spec, client, **params) }
          singleton_class.send(:public, name)
        end

        def create_client(adapter, base_uri)
          @clients[base_uri] ||= client_class(adapter).new(base_uri)
        end

        def api_spec(spec)
          {
            errors: options[:errors],
            request: spec_for_request(spec).merge!(class: request_class),
            response: spec_for_response(spec).merge!(class: response_class)
          }
        end

        def request_class
          get_or_set_constant("Request", base: Request)
        end

        def spec_for_request(spec)
          options[:conversion].merge(options[:request].deep_merge(spec[:request]))
        end

        def response_class
          get_or_set_constant("Response", base: Response)
        end

        def spec_for_response(spec)
          options[:conversion].merge(options[:response].deep_merge(spec[:response]))
        end

        def request(spec, client, **params)
          Operation.new.call(
            authorizer: options[:authorizer],
            client: client,
            spec: spec,
            **params
          )
        end
      end
    end
  end
end
