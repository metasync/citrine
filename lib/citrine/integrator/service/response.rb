# frozen-string-literal: true

module Citrine
  module Integrator
    module Service
      class Response
        attr_reader :default_spec
        attr_reader :spec
        attr_reader :status_code # HTTP status code
        attr_reader :code        # API return code
        attr_reader :message     # API return message
        attr_reader :data        # API return data

        def initialize(spec, status_code:, payload:)
          @spec = spec
          @status_code = status_code
          @payload = payload
          @code, @message, @data = parse_payload
          on_init
          validate
        end

        protected

        attr_reader :payload

        def on_init
        end

        def validate
        end

        def parse_payload
          value = parse_payload!
          [
            value.delete(:code),
            value.delete(:message),
            value.delete(:data) || value
          ]
        end

        def parse_payload!
          Schema.parse(
            spec[:result], payload,
            spec.slice(*Schema.general_options).merge(raise_on_error: true)
          )[:data]
        end
      end
    end
  end
end
