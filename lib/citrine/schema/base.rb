# frozen-string-literal: true

require_relative "attribute"

module Citrine
  class Schema
    class InvalidSchemaSpec < Error
      def initialize
        super("Schema specification MUST be a hash or a block")
      end
    end

    class << self
      def general_options
        [:date_format, :datetime_format, :time_format,
          :decimal_precision, :integer_base]
      end

      def parse(spec, data, raise_on_error: false, **opts)
        schema = new(spec: spec, **opts)
        {data: schema.parse(data, raise_on_error: raise_on_error)}.tap do |result|
          result[:error] = schema.error if schema.error?
        end
      end
    end

    attr_reader :attributes
    attr_reader :options
    attr_reader :error

    def initialize(spec: nil, **opts, &blk)
      @attributes = {}
      @options = opts
      @error = nil
      build(spec, &blk)
    end

    def attribute(name, array: false, **opts, &blk)
      attributes[name.to_sym] =
        if array
          Attribute::MultiValue.new(name, **options.merge(opts), &blk)
        else
          Attribute::SingleValue.new(name, **options.merge(opts), &blk)
        end
    end

    def parse(data, raise_on_error: true)
      @error = nil
      data ||= {}
      attributes.inject({}) do |r, (name, attribute)|
        attribute.value = data
        attribute.value.nil? ? r : r.merge!(attribute.to_h)
      end
    rescue Error => e
      @error = e
      raise if raise_on_error
      nil
    end

    def success? = error.nil?

    def error? = !success?
    alias_method :failed?, :error?

    protected

    def build(spec = nil, &blk)
      case spec
      when Hash
        build_from_hash(spec)
      when nil
        build_from_block(&blk)
      else
        raise InvalidSchemaSpec.new
      end
    end

    def build_from_hash(hash)
      hash.each_pair do |name, options|
        options ||= {}
        schema_method = if options.has_key?(:schema)
          :schema
        else
          options.has_key?(:schema_inline) ? :schema_inline : nil
        end
        schema = options[schema_method]
        opts = options.select { |k, _| k != schema_method }
        if schema_method.nil?
          attribute name, opts
        else
          attribute(name, opts).send(schema_method, spec: schema)
        end
      end
    end

    def build_from_block(&blk)
      instance_eval(&blk)
    end
  end
end
