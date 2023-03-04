# frozen-string-literal: true

module Citrine
  module Repository
    class Sql
      Model = Class.new(Sequel::Model) do
        def self.from_struct(struct)
          load(struct.to_h).tap do |m|
            m.instance_variable_set(:@new, struct.new?)
            m.instance_variable_set(:@modified, struct.modified?)
            m.changed_columns.replace(struct.changed_columns)
          end
        end

        def __model_name__
          @model_name ||= self.class.name.to_s.demodulize.underscore
        end

        def to_struct
          Struct.new(__model_name__, columns: columns, **to_hash).tap do |s|
            s.instance_variable_set(:@new, new?)
            s.instance_variable_set(:@modified, modified?)
            s.changed_columns.replace(changed_columns)
          end
        end
      end
      Model.def_Model(self)

      protected

      def create_models
        namespace = create_model_namespace
        self.class.models.each_with_object(@models) do |(name, init_blk), models|
          models[name] = create_model(name, namespace, init_blk)
        end
      end

      def create_model_namespace
        namespace = "Models_#{@database.object_id.to_s(16)}"
        if self.class.const_defined?(namespace, false)
          self.class.const_get(namespace)
        else
          self.class.const_set(namespace, Module.new)
        end
      end

      def create_model(name, namespace, init_blk)
        namespace.const_set(
          name.to_s.camelize,
          Class.new(Citrine::Repository::Sql::Model(@database.from(name.to_s.tableize)))
        ).tap do |m|
          m.class_eval(&init_blk)
        end
      end
    end
  end
end
