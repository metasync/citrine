# frozen-string-literal: true

module Citrine
  module Runner
    module Job
      class Recurring < Base
        alias_method :schedule_next_run, :start

        def run(**opts)
          super
        ensure
          schedule_next_run(wait: wait_before_next_run)
        end

        def set_default_options
          @default_options ||= super.merge!(wait: "0s")
        end

        protected

        def set_default_values
          super
          init_wait_interval
        end

        def init_wait_interval
          options[:wait] = parse_time_interval(options[:wait])
        end

        def wait_before_next_run
          options[:wait]
        end
      end
    end
  end
end
