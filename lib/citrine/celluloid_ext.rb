# frozen-string-literal: true

# Patched Celluloid::Suerpvision::Container::Pool to
# enable capability to recycle actors in an actor pool
module Celluloid
  module Supervision
    class Container
      class Pool
        def recycling? = @recycling

        def recycle(args: nil)
          return false if recycling? || ((args = Array(args)) == @args)
          @recycling = true
          @args = args
          @old_actors = @actors.to_a
          @new_actors = @size.times.map { __spawn_actor__ }
          async.recycle_next
          wait :recycled
          true
        end

        protected

        def recycle_next
          actor = __provision_actor__
          if @old_actors.include?(actor)
            unlink actor
            @busy.delete actor
            @actors.delete actor
            actor.terminate
            @idle << @new_actors.shift
          else
            @idle << actor
            @busy.delete actor
            signal :actor_idle
          end
          if @new_actors.empty?
            @recycling = false
            @old_actors = nil
            @new_actors = nil
            signal :recycled
          else
            async.recycle_next
          end
        end
      end
    end
  end
end
