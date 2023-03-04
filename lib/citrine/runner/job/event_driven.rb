# frozen-string-literal: true

module Citrine
  module Runner
    module Job
      class EventDriven < Base
        attr_reader :subscriptions

        def default_auto_start = false

        def has_subscriptions? = !@subscriptions.empty?

        def subscribe_to?(event) = @subscriptions.has_key?(event)

        def subscribe(id, event)
          actor(:runner).async.subscribe_job_to_event(id, event: event)
        end

        def unsubscribe(id, event)
          actor(:runner).async.unsubscribe_job_to_event(id, event: event)
        end

        protected

        def on_init
          @subscriptions = (@options[:subscribe] || [])
        end

        def post_init
          create_subscriptions if has_subscriptions?
          super
        end

        def create_subscriptions
          subscriptions.each { |event| subscribe(id, event: event) }
        end
      end
    end
  end
end
