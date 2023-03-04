# frozen-string-literal: true

module Citrine
  module CoreRefinements
    refine Hash do
      def symbolize_keys
        _symbolize_keys(self)
      end

      def stringify_keys
        _stringify_keys(self)
      end

      def deep_merge(other_hash, &block)
        dup.deep_merge!(other_hash, &block)
      end

      def deep_merge!(other_hash, &block)
        merge!(other_hash) do |key, this_val, other_val|
          if this_val.is_a?(Hash) && other_val.is_a?(Hash)
            this_val.deep_merge(other_val, &block)
          elsif block
            block.call(key, this_val, other_val)
          else
            other_val
          end
        end
      end

      private

      def _symbolize_keys(config)
        if config.is_a? Hash
          return config.inject({}) do |memo, (k, v)|
            memo.tap do |m|
              m[k.respond_to?(:to_sym) ? k.to_sym : k] = _symbolize_keys(v)
            end
          end
        elsif config.is_a? Array
          return config.map { |v| _symbolize_keys(v) }
        end
        config
      end

      def _stringify_keys(config)
        if config.is_a? Hash
          return config.inject({}) do |memo, (k, v)|
            memo.tap do |m|
              m[k.respond_to?(:to_s) ? k.to_s : k] = _stringify_keys(v)
            end
          end
        elsif config.is_a? Array
          return config.map { |v| _stringify_keys(v) }
        end
        config
      end
    end
  end
end
