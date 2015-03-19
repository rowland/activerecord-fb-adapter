module ActiveRecord
  module ConnectionAdapters
    module Fb
      module Quoting
        def quote(value, column = nil)
          return value.quoted_id if value.respond_to?(:quoted_id)
          type = column && column.type

          case value
          when String, ActiveSupport::Multibyte::Chars
            value = value.to_s
            if [:integer, :float].include?(type)
              (type == :integer ? value.to_i : value.to_f).to_s
            elsif !(type && type == :binary) && value.size < 256 && !value.include?('@')
              "'#{quote_string(value)}'"
            else
              "@#{Base64.encode64(value).chop}@"
            end
          else
            _quote(value)
          end
        end if ActiveRecord::VERSION::STRING < "4.2.0"

        def quote_object(obj)
          if obj.respond_to?(:to_str)
            "@#{Base64.encode64(obj.to_str).chop}@"
          else
            "@#{Base64.encode64(obj.to_yaml).chop}@"
          end
        end

        def quote_column_name(column_name) # :nodoc:
          name = ar_to_fb_case(column_name.to_s).gsub('"', '')
          @connection.dialect == 1 ? %Q(#{name}) : %Q("#{name}")
        end

        def quote_table_name_for_assignment(_table, attr)
          quote_column_name(attr)
        end if ::ActiveRecord::VERSION::MAJOR >= 4

        def unquoted_true
          boolean_domain[:true]
        end

        def quoted_true # :nodoc:
          quote unquoted_true
        end

        def unquoted_false
          boolean_domain[:false]
        end

        def quoted_false # :nodoc:
          quote unquoted_false
        end

        def type_cast(value, column)
          return super unless value == true || value == false
          value ? quoted_true : quoted_false
        end

        private

        def _quote(value)
          case value
          when String, ActiveSupport::Multibyte::Chars
            "'#{quote_string(value.to_s)}'"
          when true                  then quoted_true
          when false                 then quoted_false
          when nil                   then "NULL"
          when Numeric, ActiveSupport::Duration then value.to_s
          when BigDecimal            then value.to_s('F')
          when Date, Time            then "@#{Base64.encode64(quoted_date(value)).chop}@"
          when Symbol                then "'#{quote_string(value.to_s)}'"
          when Class                 then "'#{value}'"
          else quote_object(value)
          end
        end

        # Maps uppercase Firebird column names to lowercase for ActiveRecord;
        # mixed-case columns retain their original case.
        def fb_to_ar_case(column_name)
          column_name =~ /[[:lower:]]/ ? column_name : column_name.downcase
        end

        # Maps lowercase ActiveRecord column names to uppercase for Fierbird;
        # mixed-case columns retain their original case.
        def ar_to_fb_case(column_name)
          column_name =~ /[[:upper:]]/ ? column_name : column_name.upcase
        end
      end
    end
  end
end
