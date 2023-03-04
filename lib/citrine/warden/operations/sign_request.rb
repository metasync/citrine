# frozen-string-literal: true

module Citrine
  module Warden
    class Base
      module Operations
        class SignRequest < Citrine::Operation
          contract do
            attribute :authorizer
            attribute :request
          end

          step :parse_authorizer_name
          step :find_authorizer
          step :sign_request

          def parse_authorizer_name(context)
            context[:authorizer_name] = context[:contract][:authorizer]
          end

          def find_authorizer(context)
            context[:authorizer] = find_authorizer_by_name(context[:authorizer_name])
            if context[:authorizer].nil?
              context[:result] = UndefinedAuthorization.new(context)
              false
            else
              true
            end
          end

          def sign_request(context)
            context[:authorizer].sign_request(context[:contract][:request])
          end
        end
      end
    end
  end
end
