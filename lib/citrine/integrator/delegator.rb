# frozen-string-literal: true

module Citrine
  module Integrator
    class Delegator < Base
      using CoreRefinements

      class ServiceAPINotSupported < Error
        def initialize(api_name)
          super("Service API #{api_name.inspect} is NOT supported.")
        end
      end

      finalizer :disconnect_service

      class << self
        def api(name, delegate: name)
          define_method(name) do |**args|
            unless respond_to_api?(delegate)
              abort ServiceAPINotSupported.new(delegate)
            end
            service.send(delegate, **args).tap do |result|
              abort result.error if result.error? && abort_on_error?
            end
          end
        end
      end

      def respond_to_api?(name)
        service.respond_to?(name)
      end

      protected

      attr_reader :service

      def post_init
        super
        create_service if options[:service]
      end

      def create_service
        @service = get_or_set_constant(
          "Service", base: Citrine::Integrator::Service::Base
        ).new(service_options(options[:service]))
      end

      def disconnect_service
        service.disconnect
      end
    end
  end
end
