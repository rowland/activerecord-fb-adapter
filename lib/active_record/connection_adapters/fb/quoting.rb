module ActiveRecord
  module ConnectionAdapters
    module Fb
      module Quoting
        def quote(value, column = nil)
          # records are quoted as their primary key
          return value.quoted_id if value.respond_to?(:quoted_id)
          type = column && column.type

          case value
          when String, ActiveSupport::Multibyte::Chars
            value = value.to_s
            if [:integer, :float].include?(type)
              value = type == :integer ? value.to_i : value.to_f
              value.to_s
            elsif type && type != :binary && value.size < 256 && !value.include?('@')
              "'#{quote_string(value)}'"
            else
              "@#{Base64.encode64(value).chop}@"
            end
          when NilClass              then "NULL"
          when TrueClass, FalseClass
            if type == :integer
              value ? '1' : '0'
            else
              value ? quoted_true : quoted_false
            end
          when Float, Fixnum, Bignum then value.to_s
          # BigDecimals need to be output in a non-normalized form and quoted.
          when BigDecimal            then value.to_s('F')
          when Symbol                then "'#{quote_string(value.to_s)}'"
          when Class                 then "'#{value}'"
          else
            if value.acts_like?(:date)
              quote_date(value)
            elsif value.acts_like?(:time)
              if type == :time
                quote_time(value)
              else
                quote_timestamp(value)
              end
            else
              quote_object(value)
            end
          end
        end

        def quote_date(value)
          "'#{value.strftime("%Y-%m-%d")}'"
        end

        def quote_timestamp(value)
          usec = sprintf "%04d", (value.usec / 100.0).round
          "'#{get_time(value).strftime("%Y-%m-%d %H:%M:%S")}.#{usec}'"
        end

        def quote_time(value)
          "'#{get_time(value).strftime("%H:%M:%S")}'"
        end

        def quote_string(string) # :nodoc:
          string.gsub(/'/, "''")
        end

        def quote_object(obj)
          if obj.respond_to?(:to_str)
            "@#{Base64.encode64(obj.to_str).chop}@"
          else
            "@#{Base64.encode64(obj.to_yaml).chop}@"
          end
        end

        def quote_column_name(column_name) # :nodoc:
          if @connection.dialect == 1
            %Q(#{ar_to_fb_case(column_name.to_s)})
          else
            %Q("#{ar_to_fb_case(column_name.to_s)}")
          end
        end

        def quote_table_name_for_assignment(_table, attr)
          quote_column_name(attr)
        end if ::ActiveRecord::VERSION::MAJOR >= 4

        def quoted_true # :nodoc:
          quote(boolean_domain[:true])
        end

        def quoted_false # :nodoc:
          quote(boolean_domain[:false])
        end

        def type_cast(value, column)
          return super unless value == true || value == false
          value ? quoted_true : quoted_false
        end

        private

        def get_time(value)
          get = ::ActiveRecord::Base.default_timezone == :utc ? :getutc : :getlocal
          value.respond_to?(get) ? value.send(get) : value
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
