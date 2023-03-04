# frozen-string-literal: true

require "uri"

Sequel.default_timezone = :utc

module Citrine
  module Repository
    class Sql < Base
      using CoreRefinements

      protected

      def create_connection
        @database = Sequel.connect(database_url).tap do |db|
          db.loggers << self.class.logger if options[:enable_sql_log]
          db.extension :identifier_mangling
        end
      end

      def default_general_connection_options
        @default_general_connection_options ||=
          {preconnect: true, single_threaded: true,
           # Ensure downcasing SQL identifiers
           identifier_input_method: :downcase,
           identifier_output_method: :downcase}
      end

      def default_mysql_connection_options
        @default_mysql_connection_options ||=
          {fractional_seconds: true, encoding: "utf8mb4"}
      end

      def default_connection_options(adapter)
        case adapter
        when "mysql2", "mysql"
          default_general_connection_options.merge(default_mysql_connection_options)
        else
          default_general_connection_options
        end
      end

      def connection_options(uri)
        uri_opts = URI.decode_www_form(uri.query || "").to_h.symbolize_keys
        conn_opts = options[:connection_options] || {}
        @connection_options ||=
          default_connection_options(uri.scheme).merge(uri_opts).merge!(conn_opts)
      end

      def database_url
        URI(options[:database_url]).tap do |uri|
          uri.query = URI.encode_www_form(connection_options(uri))
        end.to_s
      end

      def connection_errors
        [Sequel::DatabaseError]
      end

      def destroy_connection
        @database.disconnect if connected?
      end

      def check_connection
        connection = @database.synchronize { |c| c }
        @database.valid_connection?(connection)
      end
    end
  end
end
