module ActiveRecord
  module ConnectionAdapters
    class FbColumn < Column # :nodoc:
      def initialize(name, domain, type, sub_type, length, precision, scale, default_source, null_flag)
        @firebird_type = ::Fb::SqlType.from_code(type, sub_type || 0)
        super(name.downcase, nil, @firebird_type, !null_flag)
        @default = parse_default(default_source) if default_source
        case @firebird_type
        when 'VARCHAR', 'CHAR'
          @limit = length
        when 'DECIMAL', 'NUMERIC'
          @precision, @scale = precision, scale.abs
        end
        @domain, @sub_type = domain, sub_type
      end

      def type
        if @domain =~ /BOOLEAN/
          :boolean
        elsif @type == :binary and @sub_type == 1
          :text
        else
          @type
        end
      end

      # Submits a _CAST_ query to the database, casting the default value to the specified SQL type.
      # This enables Firebird to provide an actual value when context variables are used as column
      # defaults (such as CURRENT_TIMESTAMP).
      def default
        if @default
          sql = "SELECT CAST(#{@default} AS #{column_def}) FROM RDB$DATABASE"
          connection = ::ActiveRecord::Base.connection
          if connection
            value = connection.raw_connection.query(:hash, sql)[0]['cast']
            return nil if value.acts_like?(:date) || value.acts_like?(:time)
            type_cast(value)
          else
            raise ConnectionNotEstablished, "No Firebird connections established."
          end
        end
      end

      def self.value_to_boolean(value)
        %W(#{FbAdapter.boolean_domain[:true]} true t 1).include? value.to_s.downcase
      end

      private

      def parse_default(default_source)
        default_source =~ /^\s*DEFAULT\s+(.*)\s*$/i
        return $1 unless $1.upcase == "NULL"
      end

      def column_def
        case @firebird_type
        when 'CHAR', 'VARCHAR'    then "#{@firebird_type}(#{@limit})"
        when 'NUMERIC', 'DECIMAL' then "#{@firebird_type}(#{@precision},#{@scale.abs})"
        #when 'DOUBLE'             then "DOUBLE PRECISION"
        else @firebird_type
        end
      end

      def simplified_type(field_type)
        if field_type == 'TIMESTAMP'
          :datetime
        else
          super
        end
      end
    end
  end
end
