# frozen-string-literal: true

module Citrine
  module Runner
    module Job
      module Batchable
        def error = result.map(&:error).compact

        def error? = !error.empty?

        protected

        def validate
          super
          unless options[:batches].is_a?(Integer) && (options[:batches] > 0)
            raise ArgumentError, "Number of batches MUST be a positive integer"
          end
          unless options[:batch_size].is_a?(Integer) && (options[:batch_size] > 0)
            raise ArgumentError, "Batch size MUST be a positive integer"
          end
          options[:run_size] = options[:batches] * options[:batch_size]
        end

        def reset_result = @result = []

        def run!
          (0...options[:batches]).to_a.map do |batch|
            actor(worker).future.send(
              operation,
              job: to_h.merge!(batch: batch,
                limit: options[:batch_size],
                offset: batch * options[:batch_size])
            )
          end.each { |batch| @result << batch.value }
        end
      end
    end
  end
end
