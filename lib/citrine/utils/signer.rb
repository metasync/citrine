# frozen-string-literal: true

require "digest/md5"
require "digest/sha1"
require "digest/sha2"

module Citrine
  module Utils
    class Signer
      using DeepSort

      VALID_SERIALIZERS = %w[json yaml]
      VALID_ALGORITHMS = %w[MD5 SHA1 SHA256 SHA384 SHA512]

      attr_reader :algorithm
      attr_reader :serializer

      class << self
        def sign(obj:, algorithm: "SHA256", serializer: "yaml")
          new(algorithm: algorithm, serializer: serializer).sign(obj)
        end
      end

      def initialize(algorithm: "SHA256", serializer: "yaml")
        @algorithm = algorithm
        @serializer = serializer
        validate
        load_serializer
        define_serialize_method
      end

      def sign(obj)
        Digest.const_get(algorithm).hexdigest(
          serialize(canonicalize(obj))
        )
      end

      protected

      def validate
        unless VALID_ALGORITHMS.include?(algorithm)
          raise ArgumentError, "Invalid signature algorithm: #{algorithm}"
        end
        unless VALID_SERIALIZERS.include?(serializer)
          raise ArgumentError, "Invalid serializer: #{serializer}"
        end
      end

      def load_serializer = require(serializer)

      def define_serialize_method
        serialize_proc =
          case serializer
          when "yaml"
            ->(obj) { obj.to_yaml }
          when "json"
            ->(obj) { JSON.pretty_generate(obj) }
          end
        define_singleton_method(:serialize, &serialize_proc)
      end

      def canonicalize(obj)
        if obj.is_a?(Array) || obj.is_a?(Hash)
          obj = obj.deep_sort_by { |obj| obj.to_s }
        end
        obj
      end
    end
  end
end
