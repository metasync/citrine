# frozen-string-literal: true

require "ostruct"

module Citrine
  module Repository
    class Struct
      include Utils::Common

      attr_reader :model
      attr_reader :columns
      attr_accessor :repository
      attr_reader :changed_columns
      attr_reader :values

      def initialize(model, columns: nil, **values)
        @model = model.to_sym
        @columns = columns || values.keys
        @values = values
        @new = true
        @modified = true
        @changed_columns = []
        create_column_accessors
      end

      def repository_assigned?
        !@repository.nil?
      end
      alias_method :persistent?, :repository_assigned?

      def new? = @new

      def modified? = @modified

      def save
        return unless persistent?
        actor(repository).send("save_#{model}", self).tap do |success|
          saved(success) if success
        end
      end

      def save_changes
        return unless persistent?
        actor(repository).send("save_#{model}_changes", self).tap do |success|
          saved(success) if success
        end
      end

      def update(hash)
        hash.each_pair { |k, v| send("#{k}=", v) }
        save_changes
      end

      def to_h
        @values.dup
      end
      alias_method :to_hash, :to_h

      protected

      def create_column_accessors
        columns.each do |c|
          define_singleton_method(c) { @values[c] }
          define_singleton_method("#{c}=") do |x|
            unless changed_columns.include?(c)
              changed_columns << c
              @modified = true
            end
            @values[c] = x
          end
        end
      end

      def saved(s)
        @new = false
        @modified = false
        @changed_columns.clear
        @values = s.values
      end
    end
  end
end
