# frozen-string-literal: true

require "http"

module Citrine
  module Integrator
    module Service
      module Client
        def self.[](adapter)
          const_get(adapter.to_s.classify)
        end

        class Base
          attr_reader :base_url

          def initialize(base_url)
            @base_url = base_url
            @client = create
          end

          %w[build_request send_request].each do |name|
            define_method(name) do |request|
              raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
            end
          end

          %w[create destroy base_error timeout_error].each do |name|
            define_method(name) do
              raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
            end
          end
        end

        class Httprb < Base
          def build_request(request)
            request =
              @client.headers(request.headers)
                .build_request(request.method, request.path, request.options)
            {method: request.verb, path: request.uri.path,
             query: request.uri.query.to_s, headers: request.headers.to_h,
             body: request.body.source.to_s}
          end

          def send_request(request)
            options = if request.spec[:verify_ssl_none]
              ctx = OpenSSL::SSL::SSLContext.new
              ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
              request.options.merge(ssl_context: ctx)
            else
              request.options
            end
            response =
              @client.timeout(request.spec[:timeout])
                .headers(request.headers)
                .send(request.method, request.path, options).flush
            {status_code: response.code, payload: response.parse}
          end

          def destroy = @client.close

          def base_error = HTTP::Error

          def timeout_error = HTTP::TimeoutError

          protected

          def create = HTTP.persistent(base_url)
        end
      end
    end
  end
end
