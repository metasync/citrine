# frozen-string-literal: true

module Citrine
  module Runner
    module Job
      class CatchUp < Recurring
        def caught_up?
          raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
        end

        def set_default_options
          @default_options ||= super.merge!(wait: "10s")
        end

        protected

        def wait_before_next_run
          caught_up? ? super : 0
        end
      end
    end
  end
end
