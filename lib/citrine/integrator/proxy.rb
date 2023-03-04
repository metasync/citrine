# frozen-string-literal: true

module Citrine
  module Integrator
    class Proxy < Base
      using CoreRefinements

      class APIServiceNotFound < Error
        def initialize(service_id)
          super("API service #{service_id.inspect} is NOT found.")
        end
      end

      class ServiceAPINotSupported < Error
        def initialize(service_id, api_name)
          super("Service API #{api_name.inspect} for #{service_id.inspect} is NOT supported.")
        end
      end

      finalizer :disconnect_services

      class << self
        def api(name, delegate: name)
          define_method(name) do |service_id, **args|
            service_id = service_id.to_sym if service_id.respond_to?(:to_sym)
            unless _has_service?(service_id)
              abort APIServiceNotFound.new(service_id)
            end
            unless _respond_to_api?(service_id, delegate)
              abort ServiceAPINotSupported.new(service_id, delegate)
            end
            service(service_id).send(delegate, **args).tap do |result|
              abort result.error if result.error? && abort_on_error?
            end
          end
        end
      end

      def has_service?(service_id)
        service_id = service_id.to_sym if service_id.respond_to?(:to_sym)
        _has_service?(service_id)
      end

      def respond_to_api?(service_id, api_name)
        service_id = service_id.to_sym if service_id.respond_to?(:to_sym)
        _respond_to_api?(service_id, api_name)
      end

      protected

      attr_reader :services

      def post_init
        super
        create_services if options[:services]
      end

      def create_services
        options[:services].each_with_object(@services = {}) do |(service_id, opts), services|
          services[service_id] = create_service(service_id, service_options(opts))
        end
      end

      def create_service(service_id, opts)
        get_or_set_constant(
          "service_#{service_id}".camelize,
          base: Citrine::Integrator::Service::Base
        ).new(**opts)
      end

      def _has_service?(service_id)
        services.has_key?(service_id)
      end

      def _respond_to_api?(service_id, api_name)
        service(service_id).respond_to?(api_name)
      end

      def service(service_id)
        services[service_id]
      end

      def disconnect_services
        services.each_value { |s| s.disconnect }
      end
    end
  end
end
