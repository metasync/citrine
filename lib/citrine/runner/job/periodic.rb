# frozen-string-literal: true

module Citrine
  module Runner
    module Job
      class Periodic < Recurring
        protected

        def set_default_values
          super
          init_run_interval if options[:every]
        end

        def init_wait_interval
          options[:wait] = 0
        end

        def init_run_interval
          options[:every] = parse_time_interval(options[:every])
        end

        def wait_before_next_run
          options[:every] - (stats[:elapsed_time] || 0)
        end

        def validate
          super
          if options[:every].nil?
            raise ArgumentError, "Run interval #every is NOT specified"
          end
        end
      end
    end
  end
end
