# frozen-string-literal: true

module Citrine
  module Integrator
    module Service
      class Operation < Citrine::Operation
        include Utils::Namespace

        class InvalidRequest < InvalidContract
          define_attribute(:request) { |ctx| ctx[:params] }
        end

        class RequestTimeout < Citrine::Operation::Result
          define_attribute(:request) { |ctx| ctx[:request].to_hash }
          message { |ctx| "Service request timetout after #{ctx[:request].spec[:timeout]} seconds" }
        end

        class ClientError < Citrine::Operation::Result
          define_attribute(:request) { |ctx| ctx[:request].to_hash }
          message { |ctx| "Service request returns error: #{ctx[:error].class.name} - #{ctx[:error].message}" }
        end

        step :build_request
        step :sign_request
        pass :send_request
        step :build_response
        pass :build_result

        def build_request(context)
          context[:request] =
            context[:spec][:request][:class].new(
              context[:spec][:request], client: context[:client], **context[:params]
            )
          if context[:request].error?
            context[:error] = context[:request].error
            context[:result] = InvalidRequest.new(context)
            false
          else
            true
          end
        end

        def sign_request(context)
          return true if context[:authorizer].nil?
          result = actor(context[:authorizer][:to]).sign_request(
            authorizer: context[:authorizer][:name],
            request: context[:request]
          )
          if result.ok?
            true
          else
            context[:result] = result
            false
          end
        end

        def send_request(context)
          context[:raw_response] = context[:client].send_request(context[:request])
        rescue context[:client].timeout_error => e
          context[:error] = e
          context[:result] = RequestTimeout.new(context)
          false
        rescue context[:client].base_error => e
          context[:error] = e
          context[:result] = ClientError.new(context)
          false
        end

        def build_response(context)
          context[:response] =
            context[:spec][:response][:class].new(
              context[:spec][:response], context[:raw_response]
            )
        end

        def build_result(context)
          context[:result] = Result.new(context)
        end

        protected

        def create_context(authorizer:, client:, spec:, **params)
          Context.new(params: params).tap do |ctx|
            ctx[:authorizer] = authorizer unless authorizer.nil?
            ctx[:client] = client
            ctx[:spec] = spec
          end
        end
      end
    end
  end
end
