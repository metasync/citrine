# frozen-string-literal: true

module Citrine
  module Utils
    module Common
      class << self
        def included(base)
          base.extend ClassMethods
        end
      end

      module ClassMethods
        def actor_alias(actor_name)
          define_method(actor_name) { actor(actor_name) }
        end

        alias_method :repository_alias, :actor_alias
      end

      def actor(name)
        Citrine::Actor[name]
      end

      def actor_registered?(name)
        !actor(name).nil?
      end
      alias_method :actor_launched?, :actor_registered?

      def registered_actors = Citrine::Actor.registered
    end
  end
end
