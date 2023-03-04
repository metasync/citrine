# frozen-string-literal: true

module Citrine
  module Integrator
    module Service
      class Operation
        class Result < Citrine::Operation::Result
          define_attribute(:request) { |ctx| ctx[:request].to_hash }
          define_attribute(:response) { |ctx| ctx[:raw_response] }
          define_attribute(:status_code) { |ctx| ctx[:response].status_code }

          code do |ctx|
            response_code = ctx[:response].code
            errors = ctx[:spec][:response][:errors]
            if errors.nil? || errors.empty?
              response_code
            else
              key = response_code.respond_to?(:to_sym) ?
                      response_code.to_sym : response_code
              errors[key] || (@unknown = true) && response_code
            end
          end

          message do |ctx|
            if ok?
              DEFAULT_SUCCESS_MESSAGE
            else
              errors = ctx[:spec][:errors]
              if errors.nil? || errors.empty?
                ctx[:response].message
              else
                key = code.respond_to?(:to_sym) ? code.to_sym : code
                errors[key] || "Unknown error (#{code}): #{ctx[:response].message}"
              end
            end
          end

          data { |ctx| ctx[:response].data }

          def initialize(context)
            @unknown = false
            super
          end

          def unknown? = @unknown
        end
      end
    end
  end
end
