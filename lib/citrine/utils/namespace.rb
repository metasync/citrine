# frozen-string-literal: true

module Citrine
  module Utils
    module Namespace
      class << self
        def included(base)
          base.extend ClassMethods
        end
      end

      module ClassMethods
        def namespace
          if defined?(@namespace)
            @namespace
          else
            @namespace = (name =~ /::[^:]+\Z/) ? $`.freeze : nil
          end
        end

        def namespace_module
          namespace ? namespace.constantize : Object
        end
      end

      def namespace
        self.class.namespace
      end

      def namespace_module
        self.class.namespace_module
      end

      def constant_defined?(name, namespace: namespace_module)
        namespace.const_defined?(name)
      end

      def get_constant(name, namespace: namespace_module)
        namespace.const_get(name)
      end

      def get_constants(mod, namespace: namespace_module, &filter)
        mod_const = get_constant(mod, namespace: namespace)
        mod_const.constants.collect { |c| mod_const.const_get(c) }
          .select { |c| filter.nil? ? true : filter.call(c) }
      end

      def set_constant(name, constant, namespace: namespace_module)
        namespace.const_set(name, constant)
      end

      def get_or_set_constant(name, base:, namespace: self.class)
        if namespace.const_defined?(name)
          namespace.const_get(name)
        else
          namespace.const_set(name, Class.new(base))
        end
      end
    end
  end
end
