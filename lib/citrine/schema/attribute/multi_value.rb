# frozen-string-literal: true

module Citrine
  class Schema
    module Attribute
      class MultiValue < SingleValue
        class NotArrayError < Error
          def initialize(name)
            super("Value for attribute #{name} MUST be an array")
          end
        end

        def array?(v = value) = v.nil? || v.is_a?(Array)

        def valid?(v = value) = array?(v) && super

        def validate(v = value)
          validate_array(v)
          super
        end

        def validate_array(v = value)
          array?(v) or raise NotArrayError.new(display_name)
        end

        def validate_type(v = value)
          type_matched?(v) or raise TypeMismatched.new(display_name, "MUST be an array of #{type}")
        end

        undef_method :schema_inline

        protected

        %i[_type_matched? _any_of? _matched? _assured?].each do |meth|
          define_method(meth) { |v| v.all? { |e| super(e) } }
        end

        %i[cast_by_schema cast_by_value!].each do |meth|
          define_method(meth) do |v|
            validate_array(v)
            v.nil? ? v : v.map! { |e| super(e) }
          end
        end
      end
    end
  end
end
