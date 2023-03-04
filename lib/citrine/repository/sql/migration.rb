# frozen-string-literal: true

require "pathname"

module Citrine
  module Repository
    class Sql
      class Migration
        include Utils::BaseObject

        def default_migration_dir
          File.join("db", "migrations", options[:database])
        end

        def default_migration_table = nil

        def migration_dir
          @migration_dir ||= init_migration_dir
        end

        def migration_table
          @migration_table ||= init_migration_table
        end

        def migrate(version: nil)
          run_migrator(target: version.nil? ? nil : Integer(version))
          "Completed migration up of #{options[:database]}"
        end

        def rollback(step: 1)
          step = Integer(step)
          down(step)
          "Completed migration down of #{options[:database]} for #{step} step(s)"
        end

        def redo(step: 1)
          step = Integer(step)
          down(step)
          up(step)
          "Completed migration redo of #{options[:database]} for #{step} step(s)"
        end

        protected

        def set_default_options
          @default_options ||= super.merge!(
            migration_dir: default_migration_dir,
            migration_table: default_migration_table
          )
        end

        def init_migration_dir
          dir = Pathname.new(options[:migration_dir] || default_migration_dir)
          dir.absolute? ? dir : options[:work_dir].join(dir)
        end

        def init_migration_table
          (options[:migration_table] || default_migration_table)&.to_sym
        end

        def step(step)
          run_migrator(relative: Integer(step))
        end
        alias_method :up, :step

        def down(step) = step(- step)

        def run_migrator(**opts)
          Sequel::Migrator.run(options[:database_connection], migration_dir,
            table: migration_table, **opts)
        end
      end

      protected

      def _run_migration!(action:, migration_dir: nil, migration_table: nil, **opts)
        load_migration_extension
        extend_schema_methods
        info Migration.new(
          database: options[:database],
          database_connection: @database,
          work_dir: options[:work_dir],
          migration_dir: migration_dir || options[:migration_dir],
          migration_table: migration_table || options[:migration_table]
        ).send(action, **opts)
      end

      def load_migration_extension
        require "sequel/core"
        Sequel.extension :migration
      end

      def extend_schema_methods
        if @database.database_type == :mssql
          extend_type_literal_mssql_string(@database)
        end
      end

      def extend_type_literal_mssql_string(db)
        db.define_singleton_method(:type_literal_generic_string) do |column|
          type = super(column)
          # use nvarchar instead of varchar for string column in MSSQL
          type.is_a?(String) ? type.gsub(/^varchar/i, "nvarchar") : type
        end
      end
    end
  end
end
