# frozen-string-literal: true

module Citrine
  module Warden
    class Base
      module Operations
        class AuthorizeRequest < Citrine::Operation
          class Success < Citrine::Operation::Success
            data { |ctx| ctx[:auth_token].slice(:access_key_id) }
          end

          contract do
            attribute :request
          end

          step :parse_auth_token
          step :find_authorizer
          step :authorize_request

          def parse_auth_token(context)
            context[:auth_token] =
              authorizer_base.parse_token(context[:contract][:request]).tap do |token|
                context[:authorizer_id] = token[:access_key_id]
              end
          end

          def find_authorizer(context)
            context[:authorizer] = find_authorizer_by_id(context[:authorizer_id])
            if context[:authorizer].nil?
              context[:result] = UndefinedAuthorization.new(context)
              false
            else
              true
            end
          end

          def authorize_request(context)
            context.merge!(context[:authorizer].authorize_request(context[:contract][:request]))
            context[:authorized] ||
              context[:result] = InvalidAuthorizationToken.new(context)
          end
        end
      end
    end
  end
end
