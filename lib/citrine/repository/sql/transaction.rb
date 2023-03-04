# frozen-string-literal: true

module Citrine
  module Repository
    class Sql
      [:save, :save_changes].each do |action|
        define_method(action) do |*structs|
          wait_for_connection
          @database.transaction do
            structs.collect do |struct|
              to_struct(models[struct.model].from_struct(struct).send(action))
            end
          end
        rescue => e
          handle_exception(e)
        end
      end

      def create(**models)
        wait_for_connection
        @database.transaction do
          models.each_pair do |name, values|
            to_struct(models[name].create(**values))
          end
        end
      rescue => e
        handle_exception(e)
      end
    end
  end
end
