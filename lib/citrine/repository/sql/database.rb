# frozen-string-literal: true

module Citrine
  module Repository
    class Sql
      protected

      def _run_sql!(sql, **opts)
        sql.call(@database, **opts)
      end

      def _table_exists?(table) = @database.table_exists?(table)

      def _schema(table) = @database.schema(table)

      def _foreign_keys(table) = @database.foreign_key_list(table)
    end
  end
end
