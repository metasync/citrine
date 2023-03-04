# frozen-string-literal: true

module Citrine
  module Warden
    class Base < Citrine::Interactor::Base
      def self.default_operation_namespace
        "Operations"
      end

      attr_reader :adapter
      attr_reader :authorizers_by_name
      attr_reader :authorizers_by_id

      operation :sign_request
      operation :authorize_request

      def authorizer_base
        Authorizer.const_get(adapter.to_s.camelize)
      end

      def find_authorizer_by_name(name)
        authorizers_by_name[name.respond_to?(:to_sym) ? name.to_sym : name]
      end

      def find_authorizer_by_id(id)
        authorizers_by_id[id.respond_to?(:to_sym) ? id.to_sym : id]
      end

      protected

      def on_init
        super
        @adapter = options[:adapter] || options[:type]
        @authorizers_by_name = {}
        @authorizers_by_id = {}
      end

      def post_init
        super
        options[:inject_methods] |= [:authorizer_base,
          :find_authorizer_by_name,
          :find_authorizer_by_id]
        create_authorizers if options[:authorizers]
      end

      def operations_module(operations_namespace)
        self.class.const_get(operations_namespace)
      end

      def create_authorizers
        options[:authorizers].each_with_object(authorizers_by_name) do |(name, spec), authorizers|
          auth_spec = options.slice(:disclose_auth_tokens).merge!(spec)
          auth_adapter = auth_spec[:adapter] || auth_spec[:type]
          authorizer = authorizer_class(auth_adapter).new(auth_spec)
          authorizers_by_name[name] = authorizer
          id = spec[:access_key_id]
          authorizers_by_id[id.respond_to?(:to_sym) ? id.to_sym : id] = authorizer
        end
      end

      def authorizer_class(adapter)
        authorizers_module.const_get(adapter.to_s.camelize)
      end

      def authorizers_module
        @authorizers_module ||= create_authorizers_module
      end

      def create_authorizers_module
        get_or_set_constant(
          "Authorizers",
          namespace: self.class.name.split("::").first.to_s.constantize,
          base: Module
        )
      end
    end
  end
end
