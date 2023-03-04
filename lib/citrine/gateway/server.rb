# frozen-string-literal: true

require_relative "reel_ext"
require "reel"
require "rack"

module Citrine
  module Gateway
    class Server < Reel::Server::HTTP
      include Celluloid::Internals::Logger
      include Utils::BaseObject

      DEFAULT_HOST = "0.0.0.0"
      DEFAULT_PORT = 3000

      class << self
        def logger = Celluloid.logger

        def registry_name
          @registry_name ||= "gateway"
        end

        def launch(supervisor, router:, **opts)
          supervisor.supervise type: self, as: registry_name, args: [router, opts]
          logger.info "Launched #{registry_name}"
        end
      end

      attr_reader :router

      def initialize(router, **opts)
        @router = router
        super(**opts)
      end

      protected

      def set_default_options
        @default_options ||= super.merge!(host: DEFAULT_HOST, port: DEFAULT_PORT)
      end

      def validate
        raise ArgumentError, "Host to bind is NOT specified." if options[:host].nil?
        raise ArgumentError, "Port to listen is NOT specified." if options[:port].nil?
      end

      def post_init
        startup_server
        show_startup_info
      end

      def show_startup_info
        puts "Powered by Reel server (Codename \"#{::Reel::CODENAME}\")"
        puts "Listening on http://#{options[:host]}:#{options[:port]}"
      end

      def startup_server
        Reel::Server::HTTP.instance_method(:initialize)
          .bind_call(self, options[:host], options[:port], &method(:on_connection))
      end

      def on_connection(connection)
        connection.each_request do |request|
          if request.websocket?
            request.respond :bad_request, "WebSockets is NOT supported yet."
          else
            route_request request
          end
        end
      end

      # Compile the regex once
      CONTENT_LENGTH_HEADER = %r{^content-length$}i

      def route_request(request)
        env = {
          :method => request.method,
          :input => request.body.to_s,
          "raw_request" => request,
          "REMOTE_ADDR" => request.remote_addr
        }.merge(convert_headers(request.headers))

        normalize_env(env)

        status, headers, body = route_request!(request.url, env)

        if body.respond_to? :each
          # If Content-Length was specified we can send the response all at once
          if headers.keys.detect { |h| h =~ CONTENT_LENGTH_HEADER }
            # Can't use collect here because Rack::BodyProxy/Rack::Lint isn't a real Enumerable
            full_body = ""
            body.each { |b| full_body += b }
            request.respond status_symbol(status), headers, full_body
          else
            request.respond status_symbol(status), headers.merge(transfer_encoding: :chunked)
            body.each { |chunk| request << chunk }
            request.finish_response
          end
        else
          error("don't know how to render: #{body.inspect}")
          request.respond :internal_server_error, "An error occurred when processing your request"
        end

        body.close if body.respond_to? :close
      end

      def route_request!(url, env)
        # Process URL as valid first
        router.call ::Rack::MockRequest.env_for(url, env)
      rescue URI::InvalidURIError
        # Retry URL with special charaters escaped if invalid
        router.call ::Rack::MockRequest.env_for(::Rack::Utils.escape_path(url), env)
      end

      # Those headers must not start with 'HTTP_'.
      NO_PREFIX_HEADERS = %w[CONTENT_TYPE CONTENT_LENGTH].freeze

      def convert_headers(headers)
        headers.map { |key, value|
          header = key.upcase.tr("-", "_")

          if NO_PREFIX_HEADERS.member?(header)
            [header, value]
          else
            ["HTTP_" + header, value]
          end
        }.to_h
      end

      # Given a Hash +env+ for the request, and and
      # fixup keys to comply with Rack's env guidelines.
      def normalize_env(env)
        if (host = env["HTTP_HOST"])
          if (colon = host.index(":"))
            env["SERVER_NAME"] = host[0, colon]
            env["SERVER_PORT"] = host[colon + 1, host.bytesize]
          else
            env["SERVER_NAME"] = host
            env["SERVER_PORT"] = default_server_port(env)
          end
        else
          env["SERVER_NAME"] = "localhost"
          env["SERVER_PORT"] = default_server_port(env)
        end
      end

      def default_server_port(env)
        (env["HTTP_X_FORWARDED_PROTO"] == "https") ? 443 : 80
      end

      def status_symbol(status)
        if status.is_a?(Integer)
          Reel::Response::STATUS_CODES[status].downcase.gsub(/\s|-/, "_").to_sym
        else
          status.to_sym
        end
      end
    end
  end
end
