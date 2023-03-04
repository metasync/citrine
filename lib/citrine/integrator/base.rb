# frozen-string-literal: true

module Citrine
  module Integrator
    class Base < Actor
      class << self
        def general_options
          [:pool_size]
        end

        def api(name, delegate: name)
          raise NotImplementedError.new("#{self.name}##{__method__} is an abstract method.")
        end
      end

      def abort_on_error?
        options[:abort_on_error]
      end

      def respond_to_api?(name)
        raise NotImplementedError.new("#{self.name}##{__method__} is an abstract method.")
      end

      protected

      def set_default_options
        @default_options ||= super.merge!(abort_on_error: true)
      end

      def default_errors
        {UnauthorizedRequest: "The request is unauthorized."}
      end

      def post_init
        create_apis if options[:apis]
      end

      def create_apis
        options[:apis].each_pair do |name, config|
          self.class.api(name, **(config || {}))
        end
      end

      def service_options(opts)
        Utils.deep_clone(opts).tap do |opts|
          if options.has_key?(:conversion)
            opts[:conversion] = options[:conversion].merge(opts[:conversion] || {})
          end
          if options.has_key?(:errors)
            opts[:errors] = default_errors.merge(options[:errors]).merge!(opts[:errors] || {})
          end
          if options.has_key?(:authorizers) && !opts[:authorizer].nil?
            opts[:authorizer] = options[:authorizers][opts[:authorizer].to_sym]
          end
        end
      end
    end
  end
end
