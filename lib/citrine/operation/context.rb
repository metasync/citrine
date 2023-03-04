# frozen-string-literal: true

require "forwardable"

module Citrine
  class Operation
    class Context
      extend Forwardable

      def_delegators :@ctx, :[], :[]=, :has_key?,
        :merge!, :dig, :slice

      def initialize(**ctx)
        @ctx = ctx
        on_init
        reset
      end

      def failed?
        !!@ctx[:error]
      end
      alias_method :error?, :failed?

      def success?
        !failed?
      end
      alias_method :pass?, :success?

      def reset
        @ctx[:failed_task] = nil
        @ctx[:error] = nil
        @ctx[:result] = nil
      end

      protected

      def on_init
        @ctx[:params] ||= {}
      end
    end
  end
end
