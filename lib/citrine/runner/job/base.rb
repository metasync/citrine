# frozen-string-literal: true

require "securerandom"

module Citrine
  module Runner
    module Job
      class Base
        class << self
          def signature_keys
            @signature_keys ||= [:name]
          end

          def generate_signature(job)
            Citrine::Utils::Signer.sign(
              algorithm: "SHA256",
              serializer: "yaml",
              obj: job.to_h.slice(*signature_keys)
            )
          end
        end

        include Utils::BaseObject
        include Utils::Common

        RUN_ID_SIZE = 4 # bytes

        attr_reader :name
        attr_reader :id
        attr_reader :worker
        attr_reader :operation
        attr_reader :next_operation
        attr_reader :summary
        attr_reader :runner
        attr_reader :run_opts
        attr_reader :run_id
        attr_reader :result
        attr_reader :stats
        attr_reader :signature

        def initialize(id:, worker:, runner:, operation: default_operation, auto_start: default_auto_start, **opts)
          @id = id
          @name = self.class.name.demodulize
          @worker = worker
          @next_operation = operation
          @runner = runner
          @auto_start = !!auto_start
          super(opts)
          @signature = self.class.generate_signature(self)
        end

        def default_operation
          self.class.name.demodulize.underscore
        end

        def [](opt_name)
          options[opt_name.to_sym]
        end

        def start(wait: nil)
          actor(runner).async.run_job(id, wait: wait)
        end

        def run(**opts)
          @run_opts = opts
          init_run
          before_run
          run!
          update_run
          post_run
        end

        def auto_start? = @auto_start

        def error = result&.error

        def error? = !error.nil?

        def failed? = error?

        def success? = !failed?

        def default_start_after = 0

        def default_auto_start = true

        def tag
          "#{name}:#{id}"
        end

        def to_h
          {id: id,
           name: name.underscore,
           auto_start: auto_start?,
           worker: worker,
           runner: runner,
           operation: operation,
           signature: signature}.merge!(options)
        end
        alias_method :to_hash, :to_h

        protected

        def on_init
          init_start_after_interval
        end

        def init_start_after_interval
          options[:start_after] =
            parse_time_interval(options[:start_after] || default_start_after)
        end

        def post_init
          start(wait: options[:start_after]) if auto_start?
        end

        def init_run
          @run_id = generate_run_id
          reset
        end

        def generate_run_id
          SecureRandom.hex(RUN_ID_SIZE)
        end

        def before_run
          stats[:start_at] = Time.now
        end

        def reset
          reset_result
          reset_states
          reset_stats
          reset_operation
        end

        def reset_operation
          @operation = @next_operation
          @summary = ""
        end

        def reset_result = @result = nil

        def reset_states
        end

        def reset_stats = @stats = {}

        def run!
          @result =
            actor(worker).send(operation, job: to_h)
        end

        def update_run
          update_states
          update_stats
          update_operation
        end

        def post_run
        end

        def update_states
        end

        def update_stats
          stats[:end_at] = Time.now
          stats[:elapsed_time] = stats[:end_at] - stats[:start_at]
        end

        def update_operation
          %w[update_next_operation update_summary].each do |action|
            "#{action}_for_#{operation}".tap { |m| send(m) if respond_to?(m, true) }
          end
        end

        def parse_time_interval(interval)
          case interval.to_s
          when /^(\d+)$/, /^(\d+)s$/ # seconds
            $1.to_i
          when /^(\d+)m$/ # minutes
            $1.to_i * 60
          when /^(\d+)h$/ # hours
            $1.to_i * 60 * 60
          when /^(\d+)d$/ # days
            $1.to_i * 60 * 60 * 24
          else
            raise ArgumentError, "Incorrect run interval is specified: #{interval.inspect}"
          end
        end

        def seconds_in_words(seconds, params = {})
          time_periods_shown = params[:time_periods_shown] || 3

          return "unknown" if seconds < 1
          [[60, :sec], [60, :min], [24, :hr], [7, :day], [52, :wk], [1000, :yr]].map { |count, name|
            if seconds > 0
              seconds, n = seconds.divmod(count)
              "#{n.to_i} #{name}" if n.to_i > 0
            end
          }.compact.last(time_periods_shown).reverse.join(" ")
        end
      end
    end
  end
end
