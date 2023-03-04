# frozen-string-literal: true

module Citrine
  class Actor
    include Celluloid
    include Celluloid::Internals::Logger
    include Utils::BaseObject
    include Utils::Namespace
    include Utils::Common

    class << self
      def enable_async_io = include(Celluloid::IO)

      def enable_notifications = include(Celluloid::Notifications)

      def [](name) = Celluloid::Actor.[](name)

      def registered = Celluloid::Actor.registered

      def logger = Celluloid.logger

      def general_options = []

      def registry_name
        @registry_name ||= name.to_s.demodulize.underscore.to_sym
      end

      def launch(supervisor, pool_size: nil, **opts)
        if pool_size.to_i > 0
          supervisor.pool self, as: registry_name, size: pool_size, args: [opts]
          logger.info "Launched #{registry_name} (pool size: #{pool_size})"
        else
          supervisor.supervise type: self, as: registry_name, args: [opts]
          logger.info "Launched #{registry_name}"
        end
      end

      def actor_self
        Citrine::Actor[registry_name]
      end
    end

    def actor_self
      self.class.actor_self
    end

    def quit(message = nil)
      error message unless message.nil?
      Process.kill("TERM", $$)
    end
  end
end
