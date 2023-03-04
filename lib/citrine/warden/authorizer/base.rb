# frozen-string-literal: true

module Citrine
  module Warden
    module Authorizer
      class Base
        extend Forwardable
        include Citrine::Utils::BaseObject

        class << self
          def parse_token(request)
            raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
          end

          def parse_authorizer_id(request)
            parse_token(request)[:access_key_id]
          end
        end

        def_delegators :@options, :[], :has_key?

        def sign_request(request)
          raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
        end

        def authorize_request(request)
          given_auth_token = get_given_auth_token(request)
          expected_auth_token = get_expected_auth_token(request)
          {authorized: given_auth_token == expected_auth_token,
           given_auth_token: given_auth_token,
           expected_auth_token: expected_auth_token,
           disclose_auth_tokens: options[:disclose_auth_tokens]}
        end

        protected

        %w[get_given_auth_token get_expected_auth_token].each do |name|
          define_method(name) do |request|
            raise NotImplementedError.new("#{self.class.name}##{__method__} is an abstract method.")
          end
        end

        def validate
          if options[:access_key_id].nil?
            raise ArgumentError, "Access key ID is NOT provided"
          end
          if options[:secret_access_key].nil?
            raise ArgumentError, "Secret access key is NOT provided"
          end
        end
      end
    end
  end
end
