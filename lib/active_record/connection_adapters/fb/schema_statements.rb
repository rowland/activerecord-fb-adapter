module ActiveRecord
  module ConnectionAdapters
    module Fb
      module SchemaStatements
        # Returns a Hash of mappings from the abstract data types to the native
        # database types.  See TableDefinition#column for details on the recognized
        # abstract data types.
        def native_database_types
          {
            :primary_key => 'integer not null primary key',
            :string      => { :name => 'varchar', :limit => 255 },
            :text        => { :name => 'blob sub_type text' },
            :integer     => { :name => 'integer' },
            :float       => { :name => 'float' },
            :decimal     => { :name => 'decimal' },
            :datetime    => { :name => 'timestamp' },
            :timestamp   => { :name => 'timestamp' },
            :time        => { :name => 'time' },
            :date        => { :name => 'date' },
            :binary      => { :name => 'blob' },
            :boolean     => { :name => boolean_domain[:name] }
          }
        end

        def tables(_name = nil)
          @connection.table_names
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name, _name = nil)
          @connection.indexes.values.map { |ix|
            if ix.table_name == table_name && ix.index_name !~ /^rdb\$/
              IndexDefinition.new(table_name, ix.index_name, ix.unique, ix.columns)
            end
          }.compact
        end

        def primary_key(table_name) #:nodoc:
          sql = <<-END_SQL
            SELECT s.rdb$field_name
            FROM rdb$indices i
            JOIN rdb$index_segments s ON i.rdb$index_name = s.rdb$index_name
            LEFT JOIN rdb$relation_constraints c ON i.rdb$index_name = c.rdb$index_name
            WHERE i.rdb$relation_name = '#{ar_to_fb_case(table_name)}'
            AND c.rdb$constraint_type = 'PRIMARY KEY';
          END_SQL
          row = select_one(sql)
          row && fb_to_ar_case(row.values.first.rstrip)
        end

        # Returns an array of Column objects for the table specified by +table_name+.
        # See the concrete implementation for details on the expected parameter values.
        def columns(table_name, _name = nil)
          column_definitions(table_name).map do |field|
            field.symbolize_keys!.each { |k, v| v.rstrip! if v.is_a?(String) }
            properties = field.values_at(:name, :default_source)
            properties += column_type_for(field)
            properties << !field[:null_flag]
            FbColumn.new(*properties, field.slice(:domain, :sub_type))
          end
        end

        def create_table(name, options = {}) # :nodoc:
          needs_sequence = options[:id] != false
          while_ensuring_boolean_domain do
            super name, options do |table_def|
              yield table_def if block_given?
              needs_sequence ||= table_def.needs_sequence
            end
          end
          return if options[:sequence] == false || !needs_sequence
          create_sequence(options[:sequence] || default_sequence_name(name))
        end

        # Unfortunately, this is a limitation of Firebird.
        def rename_table(name, new_name)
          fail ActiveRecordError, 'Firebird does not support renaming tables.'
        end

        def drop_table(name, options = {}) # :nodoc:
          super name, options
          return if options[:sequence] == false
          sequence_name = options[:sequence] || default_sequence_name(name)
          drop_sequence(sequence_name) if sequence_exists?(sequence_name)
        end

        # Creates a sequence
        # ===== Examples
        #  create_sequence('DOGS_SEQ')
        def create_sequence(sequence_name)
          execute("CREATE SEQUENCE #{sequence_name}") rescue nil
        end

        # Drops a sequence
        # ===== Examples
        #  drop_sequence('DOGS_SEQ')
        def drop_sequence(sequence_name)
          execute("DROP SEQUENCE #{sequence_name}") rescue nil
        end

        # Adds a new column to the named table.
        # See TableDefinition#column for details of the options you can use.
        def add_column(table_name, column_name, type, options = {})
          type_sql = type_to_sql(type, *options.values_at(:limit, :precision, :scale))
          add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} "\
                           "ADD #{quote_column_name(column_name)} #{type_sql}"

          add_column_options!(add_column_sql, options)
          while_ensuring_boolean_domain { execute(add_column_sql) }

          if type == :primary_key && options[:sequence] != false
            create_sequence(options[:sequence] || default_sequence_name(table_name))
          end

          return unless options[:position]
          # position is 1-based but add 1 to skip id column
          execute "ALTER TABLE #{quote_table_name(table_name)} "\
                  "ALTER COLUMN #{quote_column_name(column_name)} "\
                  "POSITION #{options[:position] + 1}"
        end

        # Changes the column's definition according to the new options.
        # See TableDefinition#column for details of the options you can use.
        # ===== Examples
        #  change_column(:suppliers, :name, :string, :limit => 80)
        #  change_column(:accounts, :description, :text)
        def change_column(table_name, column_name, type, options = {})
          type_sql = type_to_sql(type, *options.values_at(:limit, :precision, :scale))
          execute "ALTER TABLE #{quote_table_name(table_name)} "\
                  "ALTER COLUMN #{quote_column_name(column_name)} TYPE #{type_sql}"

          change_column_null(table_name, column_name, !!options[:null]) if options.key?(:null)
          change_column_default(table_name, column_name, options[:default]) if options.key?(:default)
        end

        # Sets a new default value for a column. If you want to set the default
        # value to +NULL+, you are out of luck.  You need to
        # DatabaseStatements#execute the appropriate SQL statement yourself.
        # ===== Examples
        #  change_column_default(:suppliers, :qualification, 'new')
        #  change_column_default(:accounts, :authorized, 1)
        def change_column_default(table_name, column_name, default)
          execute "ALTER TABLE #{quote_table_name(table_name)} "\
                  "ALTER #{quote_column_name(column_name)} "\
                  "SET DEFAULT #{quote(default)}"
        end

        def change_column_null(table_name, column_name, null, default = nil)
          change_column_default(table_name, column_name, default) if default

          execute "UPDATE RDB$RELATION_FIELDS "\
                  "SET RDB$NULL_FLAG=#{quote(null ? nil : 1)} "\
                  "WHERE RDB$FIELD_NAME='#{ar_to_fb_case(column_name)}' "\
                  "AND RDB$RELATION_NAME='#{ar_to_fb_case(table_name)}'"
        end

        # Renames a column.
        # ===== Example
        #  rename_column(:suppliers, :description, :name)
        def rename_column(table_name, column_name, new_column_name)
          execute "ALTER TABLE #{quote_table_name(table_name)} "\
                  "ALTER #{quote_column_name(column_name)} "\
                  "TO #{quote_column_name(new_column_name)}"

          rename_column_indexes(table_name, column_name, new_column_name)
        end

        def remove_index!(_table_name, index_name) #:nodoc:
          execute("DROP INDEX #{quote_column_name(index_name)}")
        end

        def index_name(table_name, options) #:nodoc:
          if options.respond_to?(:keys) # legacy support
            if options[:column]
              "#{table_name}_#{Array.wrap(options[:column]) * '_'}"
            elsif options[:name]
              options[:name]
            else
              fail ArgumentError, "You must specify the index name"
            end
          else
            index_name(table_name, :column => options)
          end
        end

        def type_to_sql(type, limit = nil, precision = nil, scale = nil)
          case type
          when :integer then integer_to_sql(limit)
          when :float then float_to_sql(limit)
          else super
          end
        end

        # Deprecated in Rails 4.1. Backports functionality.
        def add_column_options!(sql, options)
          if options_include_default?(options)
            sql << " DEFAULT #{quote(options[:default], options[:column])}"
          end
          # must explicitly check for :null to allow change_column to work on migrations
          sql << ' NOT NULL' if options[:null] == false
        end if ::ActiveRecord::VERSION::MAJOR > 3

        private

        def column_definitions(table_name)
          exec_query(<<-end_sql, 'SCHEMA')
            SELECT
              r.rdb$field_name name,
              r.rdb$field_source domain,
              f.rdb$field_type type,
              f.rdb$field_sub_type sub_type,
              f.rdb$field_length "limit",
              f.rdb$field_precision "precision",
              f.rdb$field_scale "scale",
              COALESCE(r.rdb$default_source, f.rdb$default_source) default_source,
              COALESCE(r.rdb$null_flag, f.rdb$null_flag) null_flag
            FROM rdb$relation_fields r
            JOIN rdb$fields f ON r.rdb$field_source = f.rdb$field_name
            WHERE r.rdb$relation_name = '#{ar_to_fb_case(table_name)}'
            ORDER BY r.rdb$field_position
          end_sql
        end

        def column_type_for(field)
          type, sub_type = field.values_at(:type, :sub_type)
          sql_type = ::Fb::SqlType.from_code(type, sub_type || 0)

          if sql_type =~ /(char|varchar)/i
            sql_type = "#{sql_type}(#{field[:limit]})"
          elsif sql_type =~ /(numeric|decimal)/i
            sql_type = "#{sql_type}(#{field[:precision]},#{field[:scale].abs})"
          end

          if ActiveRecord::VERSION::STRING < "4.2.0"
            [sql_type]
          else
            [lookup_cast_type(sql_type), sql_type]
          end
        end

        if ::ActiveRecord::VERSION::MAJOR > 3
          def create_table_definition(*args)
            TableDefinition.new(native_database_types, *args)
          end
        else
          def table_definition
            TableDefinition.new(self)
          end
        end

        # Map logical Rails types to Firebird-specific data types.
        def integer_to_sql(limit)
          return 'integer' if limit.nil?
          case limit
          when 1..2 then 'smallint'
          when 3..4 then 'integer'
          when 5..8 then 'bigint'
          else
            fail ActiveRecordError, "No integer type has byte size #{limit}. "\
                                    "Use a NUMERIC with PRECISION 0 instead."
          end
        end

        def float_to_sql(limit)
          if limit.nil? || limit <= 4
            'float'
          else
            'double precision'
          end
        end

        # Creates a domain for boolean fields as needed
        def while_ensuring_boolean_domain(&block)
          block.call
        rescue ::ActiveRecord::StatementInvalid => e
          raise unless e.message =~ /Specified domain or source column \w+ does not exist/
          create_boolean_domain
          block.call
        end

        def create_boolean_domain
          execute "CREATE DOMAIN #{boolean_domain[:name]} AS #{boolean_domain[:type]} "\
                  "CHECK (VALUE IN (#{quoted_true}, #{quoted_false}) OR VALUE IS NULL)"
        end

        def sequence_exists?(sequence_name)
          @connection.generator_names.include?(sequence_name)
        end
      end
    end
  end
end
