module ActiveRecord
  module ConnectionAdapters
    module Fb
      module Quoting
        def quote(value, column = nil)
          # records are quoted as their primary key
          return value.quoted_id if value.respond_to?(:quoted_id)

          case value
          when String, ActiveSupport::Multibyte::Chars
            value = value.to_s
            if column && [:integer, :float].include?(column.type)
              value = column.type == :integer ? value.to_i : value.to_f
              value.to_s
            elsif column && column.type != :binary && value.size < 256 && !value.include?('@')
              "'#{quote_string(value)}'"
            else
              "@#{Base64.encode64(value).chop}@"
            end
          when NilClass              then "NULL"
          when TrueClass             then (column && column.type == :integer ? '1' : quoted_true)
          when FalseClass            then (column && column.type == :integer ? '0' : quoted_false)
          when Float, Fixnum, Bignum then value.to_s
          # BigDecimals need to be output in a non-normalized form and quoted.
          when BigDecimal            then value.to_s('F')
          when Symbol                then "'#{quote_string(value.to_s)}'"
          else
            if value.acts_like?(:date)
              quote_date(value)
            elsif value.acts_like?(:time)
              quote_timestamp(value)
            else
              quote_object(value)
            end
          end
        end

        def quote_date(value)
          "@#{Base64.encode64(value.strftime('%Y-%m-%d')).chop}@"
        end

        def quote_timestamp(value)
          zone_conversion_method = ActiveRecord::Base.default_timezone == :utc ? :getutc : :getlocal
          value = value.respond_to?(zone_conversion_method) ? value.send(zone_conversion_method) : value
          "@#{Base64.encode64(value.strftime('%Y-%m-%d %H:%M:%S')).chop}@"
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

        def quote_table_name_for_assignment(table, attr)
          quote_column_name(attr)
        end if ::ActiveRecord::VERSION::MAJOR >= 4

        # Quotes the table name. Defaults to column name quoting.
        # def quote_table_name(table_name)
        #   quote_column_name(table_name)
        # end

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
