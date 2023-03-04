# frozen-string-literal: true

require "sinatra/base"
require "sinatra/json"
require "sinatra/custom_logger"

module Citrine
  module Gateway
    class Router < Sinatra::Base
      using CoreRefinements

      class Error < Citrine::Error
        def initialize(reason)
          super("#{reason.message} (#{reason.class.name.demodulize})")
        end
      end

      class InvalidRequest < Error; end

      class InvalidResult < Error; end

      include Utils::Common
      include Utils::Namespace

      helpers Sinatra::JSON
      helpers Sinatra::CustomLogger

      configure do
        enable :logging
        use Rack::CommonLogger, Actor.logger
        set :logger, Actor.logger
        set :show_exceptions, false
      end

      error do
        logger.error env["sinatra.error"].full_message
        halt_with(500, Citrine::InternalServerError.new)
      end
      error(Citrine::InternalServerError) { halt_with(500) }
      error(InvalidRequest) { halt_with(400) }

      class << self
        def bootstrap(**config)
          set :router_config, config
          set_default_values
          create_routes
        end

        protected

        def set_default_values
          router_config[:root_path] ||= "/"
          router_config[:conversion] ||= {}
          router_config[:routes] ||= {}
          router_config[:cross_origin] ||= {}
        end

        def create_routes
          router_config[:routes].each_pair do |route, config|
            config[:base_path] ||= route.to_s
            config[:parameters] ||= {}
            config[:result] = default_result_schema.deep_merge(config[:result] || {})
            config[:cross_origin] = router_config[:cross_origin].deep_merge(config[:cross_origin] || {})
            create_route(route, config)
          end
        end

        def default_result_schema
          {
            code: {type: "string"},
            message: {type: "string"},
            data: {required: false}
          }
        end

        def create_route(route, config)
          config[:apis].each_pair do |api, spec|
            spec[:authorizer] = config[:authorizer]
            spec[:delegate] ||= api
            spec[:to] ||= config[:to]
            spec[:method] ||= config[:method]
            spec[:parameters] = config[:parameters].deep_merge(spec[:parameters] || {})
            spec[:path] =
              File.join(router_config[:root_path],
                config[:base_path],
                spec[:path] || api.to_s)
            spec[:result] = config[:result].deep_merge(spec[:result] || {})
            spec[:conditions] = {}
            unless config[:vhost].nil?
              spec[:conditions][:host_name] = /^#{config[:vhost]}$/
            end
            spec[:cross_origin] = config[:cross_origin].deep_merge(spec[:cross_origin] || {})
            create_api(spec)
          end
        end

        def allow_cross_origin?(spec)
          !!spec[:cross_origin][:allow_origin]
        end

        def create_api(spec)
          spec = api_spec(spec)
          if allow_cross_origin?(spec)
            spec[:cross_origin] = default_cross_origin_options.merge(spec[:cross_origin])
            # create OPTIONS api to handle preflight requests for CORS if any
            send(:options, spec[:path], **spec[:conditions]) { route_preflight_request(spec) }
            send(spec[:method].to_sym, spec[:path], **spec[:conditions]) { route_cors_request(spec) }
          else
            send(spec[:method].to_sym, spec[:path], **spec[:conditions]) { route_request(spec) }
          end
        end

        def api_spec(spec)
          spec.tap do |s|
            %i[conversion].each do |section|
              if router_config.has_key?(section)
                s[section] = router_config[section].merge(s[:section] || {})
              end
            end
          end
        end

        def default_cross_origin_options
          {
            allow_methods: ["post", "get", "options"],
            allow_credentials: true,
            allow_headers: ["*", "Content-Type", "Accept", "Authorization", "Cache-Control"],
            max_age: 1728000,
            expose_headers: ["Cache-Control", "Content-Language", "Content-Type", "Expires", "Last-Modified", "Pragma"]
          }
        end
      end

      [:debug, :info, :warn, :error].each do |level|
        define_method(level) do |string|
          logger.send(level, string)
        end
      end

      protected

      def router_config = settings.router_config

      def authorize_request(authorizer)
        actor(authorizer).authorize_request(request: env["raw_request"])
      end

      def cross_origin(**opts)
        request_origin = request.env["HTTP_ORIGIN"]
        return unless request_origin

        if opts[:allow_origin] == "any"
          origin = request_origin
        else
          allowed_origins = *opts[:allow_origin]
          origin = allowed_origins.join("|") # default origin if no matching
          allowed_origins.each do |allowed_origin|
            if allowed_origin.is_a?(Regexp) ?
                request_origin =~ allowed_origin :
                request_origin == allowed_origin
              origin = request_origin
              break
            end
          end
        end

        headers_list = {
          "Access-Control-Allow-Origin" => origin,
          "Access-Control-Allow-Methods" => opts[:allow_methods].map(&:upcase).join(", "),
          "Access-Control-Allow-Headers" => opts[:allow_headers].map(&:to_s).join(", "),
          "Access-Control-Allow-Credentials" => opts[:allow_credentials].to_s,
          "Access-Control-Max-Age" => opts[:max_age].to_s,
          "Access-Control-Expose-Headers" => opts[:expose_headers].join(", ")
        }

        headers headers_list
      end

      def route_preflight_request(spec)
        cross_origin(spec[:cross_origin])
        200
      end

      def route_cors_request(spec)
        cross_origin(spec[:cross_origin])
        route_request(spec)
      end

      def route_request(spec)
        env["citrine.api.spec"] = spec
        result = authorize_request(spec[:authorizer]) if spec[:authorizer]
        if result.nil? || result.ok?
          extract_request_params
          params.merge!(result.data) unless result.nil?
          parameters = convert_params(params)
          result = dispatch_request(parameters)
        else
          logger.error "Unauthorized request: #{result.message} (#{result.code})"
        end
        response = convert_result(result.to_hash)
        json response
      end

      def extract_request_params
        if (request.media_type == "application/json") &&
            (request.content_length.to_i > 0)
          request.body.rewind
          params.merge!(JSON.parse(request.body.read))
        end
      end

      def convert_params(params, spec = env["citrine.api.spec"])
        result = Schema.parse(spec[:parameters], params,
          spec[:conversion].merge(raise_on_error: false))
        raise InvalidRequest.new(result[:error]) if result[:error]
        result[:data]
      end

      def dispatch_request(params, spec = env["citrine.api.spec"])
        actor(spec[:to].to_sym).send(spec[:delegate], params)
      end

      def convert_result(result, spec = env["citrine.api.spec"])
        result = Schema.parse(spec[:result], result,
          spec[:conversion].merge(raise_on_error: false))
        raise InvalidResult.new(result[:error]) if result[:error]
        result[:data]
      end

      def halt_with(status_code, error = env["sinatra.error"])
        halt status_code,
          {"Content-Type" => "application/json"},
          convert_result({code: error.class.name.demodulize,
                           message: error.message}).to_json
      end
    end
  end
end
