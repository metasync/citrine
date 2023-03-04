# frozen-string-literal: true

module Citrine
  module Interactor
    class Base < Actor
      class << self
        def general_options = [:pool_size]

        def operations_namespace(ns = nil)
          if ns.nil?
            @operations_namespace ||= default_operation_namespace
          else
            @operations_namespace = ns
          end
        end

        def default_operation_namespace
          name.demodulize.gsub(/Interactor$/, "") + "Operations"
        end

        def operation(name, to: name, namespace: operations_namespace)
          define_method(name) do |opts = {}|
            run_operation(to, namespace: namespace, **opts)
          end
        end
      end

      %i[inject_schemes inject_configs inject_methods].each do |m|
        define_method("has_#{m}?") { !options[m].empty? }
      end

      protected

      def set_default_values
        super.tap do |options|
          options[:inject_schemes] ||= {}
          options[:inject_configs] ||= []
          options[:inject_methods] ||= []
        end
      end

      def post_init
        define_operations if options[:operations]
      end

      def define_operations
        options[:operations].each_pair do |name, config|
          self.class.operation(name, **(config || {}))
        end
      end

      def run_operation(name, namespace:, **opts)
        create_operation(name, namespace: namespace).call(**opts).tap do |result|
          if result.error?
            if result.ignore_error?
              warn result.error.message
            else
              error result.error.full_message
            end
          end
          abort InternalServerError.new if result.is_a?(Operation::Failure)
        end
      end

      def create_operation(name, namespace:)
        get_operation(name, namespace: namespace).new.tap do |operation|
          inject_dependencies_to_operation(operation)
        end
      end

      def get_operation(name, namespace:)
        operations_module(namespace).const_get(name.to_s.camelize)
      end

      def operations_module(operations_namespace)
        namespace_module.const_get(operations_namespace)
      end

      def inject_dependencies_to_operation(operation)
        inject_schemes_to_operation(operation) if has_inject_schemes?
        inject_configs_to_operation(operation) if has_inject_configs?
        inject_methods_to_operation(operation) if has_inject_methods?
      end

      def inject_schemes_to_operation(operation)
        options[:inject_schemes].each_pair do |name, scheme|
          operation.define_singleton_method(name) { scheme }
        end
      end

      def inject_configs_to_operation(operation)
        options.slice(*options[:inject_configs].map!(&:to_sym)).each_pair do |k, v|
          operation.define_singleton_method(k) { v }
        end
      end

      def inject_methods_to_operation(operation)
        options[:inject_methods].map!(&:to_sym).each do |m|
          interactor = self
          if self.class.method_defined?(m)
            operation.define_singleton_method(m) do |*args|
              interactor.send(m, *args)
            end
          end
        end
      end
    end
  end
end
