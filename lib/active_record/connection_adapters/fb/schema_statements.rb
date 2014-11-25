module ActiveRecord
  module ConnectionAdapters
    module Fb
      module SchemaStatements
        # Returns a Hash of mappings from the abstract data types to the native
        # database types.  See TableDefinition#column for details on the recognized
        # abstract data types.
        def native_database_types
          {
            :primary_key => "integer not null primary key",
            :string      => { :name => "varchar", :limit => 255 },
            :text        => { :name => "blob sub_type text" },
            :integer     => { :name => "integer" },
            :float       => { :name => "float" },
            :decimal     => { :name => "decimal" },
            :datetime    => { :name => "timestamp" },
            :timestamp   => { :name => "timestamp" },
            :time        => { :name => "time" },
            :date        => { :name => "date" },
            :binary      => { :name => "blob" },
            :boolean     => { :name => boolean_domain[:name] }
          }
        end

        # Truncates a table alias according to the limits of the current adapter.
        # def table_alias_for(table_name)
        #   table_name[0..table_alias_length-1].gsub(/\./, '_')
        # end

        # def tables(name = nil) end
        def tables(name = nil)
          @connection.table_names
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name, name = nil)
          result = @connection.indexes.values.select {|ix| ix.table_name == table_name && ix.index_name !~ /^rdb\$/ }
          indexes = result.map {|ix| IndexDefinition.new(table_name, ix.index_name, ix.unique, ix.columns) }
          indexes
        end

        def primary_key(table_name) #:nodoc:
          sql = <<-END_SQL
            SELECT s.rdb$field_name
            FROM rdb$indices i
            JOIN rdb$index_segments s ON i.rdb$index_name = s.rdb$index_name
            LEFT JOIN rdb$relation_constraints c ON i.rdb$index_name = c.rdb$index_name
            WHERE i.rdb$relation_name = '#{ar_to_fb_case(table_name)}' and c.rdb$constraint_type = 'PRIMARY KEY';
          END_SQL
          row = select_one(sql)
          row && fb_to_ar_case(row.values.first.rstrip)
        end

        # Returns an array of Column objects for the table specified by +table_name+.
        # See the concrete implementation for details on the expected parameter values.
        def columns(table_name, name = nil)
          sql = <<-END_SQL
            SELECT r.rdb$field_name, r.rdb$field_source, f.rdb$field_type, f.rdb$field_sub_type,
                   f.rdb$field_length, f.rdb$field_precision, f.rdb$field_scale,
                   COALESCE(r.rdb$default_source, f.rdb$default_source) rdb$default_source,
                   COALESCE(r.rdb$null_flag, f.rdb$null_flag) rdb$null_flag
            FROM rdb$relation_fields r
            JOIN rdb$fields f ON r.rdb$field_source = f.rdb$field_name
            WHERE r.rdb$relation_name = '#{ar_to_fb_case(table_name)}'
            ORDER BY r.rdb$field_position
          END_SQL
          select_rows(sql, name).collect do |field|
            field_values = field.collect do |value|
              case value
                when String then value.rstrip
                else value
              end
            end
            FbColumn.new(*field_values)
          end
        end

        def create_table(name, options = {}) # :nodoc:
          begin
            super
          rescue
            raise unless non_existent_domain_error?
            create_boolean_domain
            super
          end
          unless options[:id] == false || options[:sequence] == false
            sequence_name = options[:sequence] || default_sequence_name(name)
            create_sequence(sequence_name)
          end
        end

        def drop_table(name, options = {}) # :nodoc:
          super(name)
          unless options[:sequence] == false
            sequence_name = options[:sequence] || default_sequence_name(name)
            drop_sequence(sequence_name) if sequence_exists?(sequence_name)
          end
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
          add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(add_column_sql, options)
          begin
            execute(add_column_sql)
          rescue
            raise unless non_existent_domain_error?
            create_boolean_domain
            execute(add_column_sql)
          end
          if options[:position]
            # position is 1-based but add 1 to skip id column
            alter_position_sql = "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} POSITION #{options[:position] + 1}"
            execute(alter_position_sql)
          end
        end

        # Changes the column's definition according to the new options.
        # See TableDefinition#column for details of the options you can use.
        # ===== Examples
        #  change_column(:suppliers, :name, :string, :limit => 80)
        #  change_column(:accounts, :description, :text)
        def change_column(table_name, column_name, type, options = {})
          sql = "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} TYPE #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(sql, options)
          execute(sql)
        end

        # Sets a new default value for a column.  If you want to set the default
        # value to +NULL+, you are out of luck.  You need to
        # DatabaseStatements#execute the appropriate SQL statement yourself.
        # ===== Examples
        #  change_column_default(:suppliers, :qualification, 'new')
        #  change_column_default(:accounts, :authorized, 1)
        def change_column_default(table_name, column_name, default)
          execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} SET DEFAULT #{quote(default)}")
        end

        # Renames a column.
        # ===== Example
        #  rename_column(:suppliers, :description, :name)
        def rename_column(table_name, column_name, new_column_name)
          execute "ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
        end

        def remove_index!(table_name, index_name) #:nodoc:
          execute("DROP INDEX #{quote_column_name(index_name)}")
        end

        def index_name(table_name, options) #:nodoc:
          if Hash === options # legacy support
            if options[:column]
              "#{table_name}_#{Array.wrap(options[:column]) * '_'}"
            elsif options[:name]
              options[:name]
            else
              raise ArgumentError, "You must specify the index name"
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

      private
        # Map logical Rails types to Firebird-specific data types.
        def integer_to_sql(limit)
          return 'integer' if limit.nil?
          case limit
            when 1..2 then 'smallint'
            when 3..4 then 'integer'
            when 5..8 then 'bigint'
            else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a NUMERIC with PRECISION 0 instead.")
          end
        end

        def float_to_sql(limit)
          if limit.nil? || limit <= 4
            'float'
          else
            'double precision'
          end
        end

        def non_existent_domain_error?
          $!.message =~ /Specified domain or source column \w+ does not exist/
        end

        def create_boolean_domain
          sql = <<-end_sql
            CREATE DOMAIN #{boolean_domain[:name]} AS #{boolean_domain[:type]}
            CHECK (VALUE IN (#{quoted_true}, #{quoted_false}) OR VALUE IS NULL)
          end_sql
          execute(sql)
        end

        def sequence_exists?(sequence_name)
          @connection.generator_names.include?(sequence_name)
        end
      end
    end
  end
end
