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
            elsif type && type == :binary
              "@BINDBINARY#{Base64.encode64(value.to_s)}BINDBINARY@"
            else
              "'#{quote_string(value)}'"
            end
          when Date, Time
            "@BINDDATE#{quoted_date(value)}BINDDATE@"
          else
            super
          end
        end if ActiveRecord::VERSION::STRING < "4.2.0"

        def quote_string(string) # :nodoc:
          string.gsub(/'/, "''")
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
          if [true, false].include?(value)
            value ? quoted_true : quoted_false
          else
            super
          end
        end

        private

        # Types that are bind parameters will not be quoted
        def _quote(value)
          case value
          when Type::Binary::Data
            "@BINDBINARY#{Base64.encode64(value.to_s)}BINDBINARY@"
          when Date, Time
            "@BINDDATE#{quoted_date(value)}BINDDATE@"
          else
            super
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

        if defined? Encoding
          def decode(s)
            Base64.decode64(s).force_encoding(@connection.encoding)
          end
        else
          def decode(s)
            Base64.decode64(s)
          end
        end
      end
    end
  end
end
