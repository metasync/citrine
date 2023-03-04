# frozen-string-literal: true

require "time"
require "date"

module Citrine
  class Schema
    module Attribute
      class SingleValue
        class TypeMismatched < Error
          def initialize(name, reason)
            super("Type MISMATCHED for attribute #{name}: #{reason}")
          end
        end

        class MissingRequiredAttribute < Error
          def initialize(name)
            super("Missing required attribute #{name}")
          end
        end

        class InvalidAttributeValue < Error
          def initialize(name, reason)
            super("Invalid value for attribute #{name}: #{reason}")
          end
        end

        class TypeCastingError < Error
          def initialize(name, reason)
            super("Failed to cast attribute #{name}: #{reason}")
          end
        end

        DEFAULT_DATE_FORMAT = "%Y-%m-%d"
        DEFAULT_DATETIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%L"
        DEFAULT_TIME_FORMAT = DEFAULT_DATETIME_FORMAT
        DEFAULT_DECIMAL_PRECISION = 2
        DEFAULT_INTEGER_BASE = 10

        attr_reader :name
        attr_reader :display_name
        attr_reader :bind_to
        attr_reader :map
        attr_reader :type
        attr_reader :default
        attr_reader :options
        attr_reader :value

        def initialize(name,
          bind_to: nil,
          map: nil,
          type: nil,
          required: default_imperative,
          default: nil,
          any_of: [],
          match: nil,
          assure: nil,
          **opts, &blk)
          @name = name.to_sym
          @display_name = name.to_s.upcase
          @bind_to = bind_to&.to_sym
          @map = map
          @inline = false
          @type = type&.to_sym&.downcase
          @required = !!required
          @default = default
          @any_of = any_of
          @match = match
          @assurance = assure
          @handler = blk || ->(v) { v }
          @options = default_options.merge(opts)
          @schema = nil
          verify
          reset
        end

        def default_imperative = true

        def reset
          @value = default
        end

        def default_options
          @default_options ||= {
            date_format: DEFAULT_DATE_FORMAT,
            datetime_format: DEFAULT_DATETIME_FORMAT,
            time_format: DEFAULT_TIME_FORMAT,
            decimal_precision: DEFAULT_DECIMAL_PRECISION,
            integer_base: DEFAULT_INTEGER_BASE
          }
        end

        def value=(v)
          set(v)
        end

        def set(v) = set!(v).tap { |r| validate(r) }

        def set!(v) = @value = process(v)

        def inline? = @inline

        def typed? = !@type.nil?

        def required? = @required

        def optional? = !required?
        alias_method :nullable?, :optional?
        def has_default? = !default.nil?

        def valid?(v = value)
          !missing?(v) && type_matched? && any_of?(v) && matched?(v) && assured?(v)
        end

        def missing?(v = value) = required? && v.nil?

        def type_matched?(v = value)
          !typed? || (v.nil? && nullable?) || _type_matched?(v)
        end

        def any_of?(v = value) = @any_of.empty? || _any_of?(v)

        def matched?(v = value) = @match.nil? || _matched?(v)

        def assured?(v = value) = @assurance.nil? || _assured?(v)

        def validate(v = value)
          validate_required(v)
          validate_type(v)
          validate_any_of(v)
          validate_match(v)
          validate_assurance(v)
        end

        def validate_type(v = value)
          type_matched?(v) or raise TypeMismatched.new(display_name, "MUST be an instance of #{type}")
        end

        def validate_required(v = value)
          !missing?(v) or raise MissingRequiredAttribute.new(display_name)
        end

        def validate_any_of(v = value)
          any_of?(v) or raise InvalidAttributeValue.new(display_name, "#{v.inspect} is NOT one of #{@any_of.join(", ")}")
        end

        def validate_match(v = value)
          matched?(v) or raise InvalidAttributeValue.new(display_name, "#{v.inspect} does NOT match #{@match.inspect}")
        end

        def validate_assurance(v = value)
          assured?(v) or raise InvalidAttributeValue.new(display_name, "#{v.inspect} does NOT meet the assurance.")
        end

        def has_schema? = !@schema.nil?

        def schema_inline(spec: nil, **opts, &blk)
          @inline = true
          define_singleton_method(:to_h) { value }
          new_schema(spec: spec, **opts, &blk)
        end

        def schema(spec: nil, **opts, &blk)
          if options[:uplift]
            define_singleton_method(:to_h) { value }
          else
            define_singleton_method(:to_h) { {(bind_to || name) => value} }
          end
          new_schema(spec: spec, **opts, &blk)
        end

        def to_h
          {
            (bind_to || name) =>
            if map.nil?
              value
            else
              map[value.respond_to?(:to_sym) ? value.to_sym : value]
            end
          }
        end
        alias_method :to_hash, :to_h

        protected

        def verify
          unless @type.nil?
            verify_type
            verify_default unless @default.nil?
          end
          verify_any_of unless @any_of.empty?
          verify_match unless @match.nil?
          verify_assurance unless @assurance.nil?
        end

        def verify_type
          unless respond_to?(cast_method(type), true)
            raise ArgumentError, "UNKNOWN type for attribute #{display_name}: #{type}"
          end
        end

        def verify_default
          validate(default)
        end

        def verify_any_of
          unless @any_of.respond_to?(:include?)
            raise ArgumentError, "List of values for attribute #{display_name} MUST respond to #include?"
          end
        end

        def verify_match
          unless @match.respond_to?(:match)
            raise ArgumentError, "Matching pattern of attribute #{display_name} MUST respond to #match"
          end
        end

        def verify_assurance
          unless @assurance.respond_to?(:call)
            raise ArgumentError, "Assurance of attribute #{display_name} must respond to #call"
          end
        end

        def _type_matched?(v) = send("#{type}?", v)

        def _any_of?(v) = @any_of.include?(v)

        def _matched?(v) = !!@match.match(v.to_s)

        def _assured?(v) = !!@assurance.call(v)

        def process(value)
          v = set_default_value(extract_value(value))
          @handler.call(has_schema? ? cast_by_schema(v) : cast_by_value(v))
        end

        def extract_value(value)
          if inline?
            extract_value_by_schema(value)
          else
            extract_value_by_key(value)
          end
        end

        def extract_value_by_schema(value)
          d = @schema.attributes.each_with_object({}) do |(k, _), r|
            v = extract_value_by_key(value, key: k)
            r[k] = v unless v.nil?
          end
          d.empty? ? nil : d
        end

        def extract_value_by_key(value, key: name)
          if value.has_key?(key.to_sym)
            value[key.to_sym]
          elsif value.has_key?(key.to_s)
            value[key.to_s]
          end
        end

        def set_default_value(value)
          (has_default? && value.nil?) ? default : value
        end

        def cast_by_schema(value)
          value.nil? ? value : @schema.parse(value)
        end

        def cast_by_value(value)
          return value if value.nil? || !typed?
          cast_by_value!(value)
        rescue => e
          raise TypeCastingError.new(display_name, "#{e.class.name} - #{e.message}")
        end

        def cast_by_value!(value)
          if send("#{type}?", value)
            value
          else
            send(cast_method(type), value)
          end
        end

        def cast_method(type) = "cast_#{type}"

        def cast_string(value)
          case value
          when Time
            value.strftime(options[:time_format])
          when DateTime
            value.strftime(options[:datetime_format])
          when Date
            value.strftime(options[:date_format])
          else
            String(value)
          end
        end

        def cast_integer(value) = Integer(value, options[:integer_base])

        def cast_float(value) = Float(value)

        def cast_decimal(value) = Float(value).round(options[:decimal_precision])

        def cast_symbol(value) = value.to_sym

        def cast_time(value) = Time.strptime(value, options[:time_format])

        def cast_date(value) = Date.strptime(value, options[:date_format])

        def cast_datetime(value) = DateTime.strptime(value, options[:datetime_format])

        def cast_bool(value)
          return false if value == "false"
          return true if value == "true"
          !!value
        end

        def string?(value) = value.is_a?(String)

        def integer?(value) = value.is_a?(Integer)

        def float?(value) = value.is_a?(Float)
        alias_method :decimal?, :float?
        def symbol?(value) = value.is_a?(Symbol)

        def time?(value) = value.is_a?(Time)

        def date?(value) = value.is_a?(Date)

        def datetime?(value) = value.is_a?(DateTime)

        def bool?(value) = value.is_a?(TrueClass) || value.is_a?(FalseClass)

        def new_schema(spec: nil, **opts, &blk)
          @schema = Schema.new(spec: spec, **options.merge(opts), &blk)
        end
      end
    end
  end
end
