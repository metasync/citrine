# frozen-string-literal: true

require_relative "job"

module Citrine
  module Runner
    class Base < Actor
      using CoreRefinements

      enable_notifications

      attr_reader :jobs
      attr_reader :subscriptions

      def add_jobs(jobs)
        case jobs
        when Hash
          add_jobs(
            jobs.inject([]) do |j, (name, opts)|
              case opts[:jobs]
              when Hash
                j.concat(opts[:jobs].each_with_object([]) { |(id, job), jobs|
                  jobs << {name: name, id: id.to_s}.merge!(opts[:general] || {}).deep_merge!(job)
                })
              when Array
                j.concat(opts[:jobs].map { |job|
                  {name: name}.merge!(opts[:general] || {}).deep_merge!(job)
                })
              else
                raise ArgumentError, "Invalid jobs: #{jobs.inspect}"
              end
            end
          )
        when Array
          jobs.each do |job|
            add_job(**job).tap { |j| puts "Added job #{j.tag}" }
          end
        else
          raise ArgumentError, "Invalid jobs: #{jobs.inspect}"
        end
        true
      rescue => e
        handle_exception(e)
        false
      end

      def run_job(id, opts = {})
        return unless has_job?(id) && applicable_job?(jobs[id])
        wait = opts[:wait]
        if wait.nil? || (wait <= 0)
          run_job!(id, opts)
        else
          after(wait) { run_job!(id, opts) }
        end
      end

      def remove_job(id)
        jobs.delete(id)
      end

      def remove_jobs(*ids)
        ids.each { |id| remove_job(id) }
      end

      def has_job?(id)
        jobs.has_key?(id)
      end

      def applicable_job?(job)
        @job_filter.call(job.to_h)
      end

      def find_jobs(opts = {})
        jobs.transform_values(&:to_h).select do |id, job|
          opts.reduce(true) { |found, (k, v)| found && job[k] == v }
        end
      end

      def subscribe_job_to_event(id, event:)
        s = subscribers(event)
        s[id] = subscribe(event, :fire_event) unless s.has_key?(id)
      end

      def unsubscribe_job_to_event(id, event:)
        unsubscribe(subscribers(event).delete(id))
      end

      def has_subscribers?(event)
        subscriptions.has_key?(evnet) && !subscribers(event).empty?
      end

      def fire_event(event, **payload)
        if has_subscribers?(event)
          subscribers(event).each do |id|
            async.run_job(id, event: event, payload: payload)
          end
        end
      end

      protected

      def on_init
        @jobs = {}
        @job_filter = parse_job_filter
        @subscriptions = {}
      end

      def parse_job_filter
        filter_opts = (options[:job_filter] || "").split(":")
        filter, key, value =
          case filter_opts.size
          when 0, 3
            []
          when 1
            ["select", "name"]
          when 2
            ["select"]
          end.concat(filter_opts)
        filter = filter&.to_sym
        key = key&.to_sym
        case filter
        when :select
          ->(job) { job[key] =~ /#{value}/ }
        when :reject
          ->(job) { job[key] !~ /#{value}/ }
        else
          ->(job) { true }
        end
      end

      def post_init
        unless options[:jobs].empty?
          after(0.1) { add_jobs(options[:jobs]) }
        end
      end

      def add_job(**job)
        jobs[job[:id]] = create_job(**job) unless has_job?(job[:id])
      end

      def create_job(name:, **job)
        job[:runner] = self.class.registry_name
        job_class(name).new(**job)
      end

      def job_class(name)
        get_constant("jobs/#{name}".to_s.camelize)
      end

      def run_job!(id, opts)
        jobs[id].tap do |job|
          job.run(**opts)
          info "#{job.summary} [#{job.tag}-rid##{job.run_id}]" unless job.summary.empty?
        end
      rescue => e
        handle_exception(e)
      end

      def handle_exception(exception)
        error exception.full_message
      end

      def subscribers(event)
        subscriptions[event] ||= {}
      end
    end
  end
end
