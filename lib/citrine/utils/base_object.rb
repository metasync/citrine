# frozen-string-literal: true

module Citrine
  module Utils
    module BaseObject
      attr_reader :options
      attr_reader :default_options

      def initialize(opts = {})
        @options = opts
        yield @options if block_given?
        set_default_options
        on_init
        set_default_values
        validate
        post_init
      end

      protected

      def set_default_options
        @default_options ||= {}
      end

      def set_default_values
        @options = default_options.merge(@options)
      end

      def on_init
      end

      def validate
      end

      def post_init
      end
    end
  end
end
