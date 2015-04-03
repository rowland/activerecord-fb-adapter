module ActiveRecord
  module ConnectionAdapters
    class FbColumn < Column # :nodoc:
      class << self
        delegate :boolean_domain, to: 'ActiveRecord::ConnectionAdapters::FbAdapter'

        # When detecting types, ActiveRecord expects strings in a certain format.
        # In 4.2, these strings are converted to ActiveRecord::Type::Value objects
        # using the type_map (see #initialize_type_map). Prior to 4.2, the sql_type
        # could be coerced to a certain ActiveRecord type in Column#simplified_type.
        def sql_type_for(field)
          type, sub_type, domain = field.values_at(:type, :sub_type, :domain)
          sql_type = ::Fb::SqlType.from_code(type, sub_type || 0).downcase

          case sql_type
          when /(numeric|decimal)/
            sql_type << "(#{field[:precision]},#{field[:scale].abs})"
          when /(int|float|double|char|varchar)/
            sql_type << "(#{field[:limit]})"
          end

          sql_type << ' sub_type text' if sql_type =~ /blob/ && sub_type == 1
          sql_type = 'boolean' if domain =~ %r(#{boolean_domain[:name]})i
          sql_type
        end
      end

      attr_reader :sub_type, :domain

      if ActiveRecord::VERSION::STRING < "4.2.0"
        def initialize(name, default, sql_type = nil, null = true, fb_options = {})
          @domain, @sub_type = fb_options.values_at(:domain, :sub_type)
          super(name.downcase, parse_default(default), sql_type, null)
        end
      else
        def initialize(name, default, cast_type, sql_type = nil, null = true, fb_options = {})
          @domain, @sub_type = fb_options.values_at(:domain, :sub_type)
          super(name.downcase, parse_default(default), cast_type, sql_type, null)
        end
      end

      private

      def parse_default(default)
        return if default.nil? || default =~ /null/i
        default.gsub(/^\s*DEFAULT\s+/i, '').gsub(/(^'|'$)/, '')
      end

      # Type conversion prior to 4.2
      def simplified_type(field_type)
        return :datetime if field_type =~ /timestamp/
        return :text if field_type =~ /blob sub_type text/
        super
      end
    end
  end
end
