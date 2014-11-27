module ActiveRecord
  module ConnectionAdapters
    module Fb
      module DatabaseStatements
        # Returns an array of arrays containing the field values.
        # Order is the same as that returned by +columns+.
        def select_rows(sql, name = nil, binds = [])
          exec_query(sql, name, binds).to_a.map(&:values)
        end

        # Executes the SQL statement in the context of this connection.
        def execute(sql, name = nil, skip_logging = false)
          translate(sql) do |translated, args|
            if (name == :skip_logging) || skip_logging
              @connection.execute(translated, *args)
            else
              log(sql, args, name) do
                @connection.execute(translated, *args)
              end
            end
          end
        end

        # Executes +sql+ statement in the context of this connection using
        # +binds+ as the bind substitutes. +name+ is logged along with
        # the executed +sql+ statement.
        def exec_query(sql, name = 'SQL', binds = [])
          translate(sql, binds) do |translated, args|
            log(expand(translated, args), name) do
              result, rows = @connection.execute(translated, *args) do |cursor|
                [cursor.fields, cursor.fetchall]
              end
              next result unless result.respond_to?(:map)
              cols = result.map { |col| col.name }
              ActiveRecord::Result.new(cols, rows)
            end
          end
        end

        def explain(arel, binds = [])
          to_sql(arel, binds)
        end

        # Checks whether there is currently no transaction active. This is done
        # by querying the database driver, and does not use the transaction
        # house-keeping information recorded by #increment_open_transactions and
        # friends.
        #
        # Returns true if there is no transaction active, false if there is a
        # transaction active, and nil if this information is unknown.
        def outside_transaction?
          !@connection.transaction_started
        end

        # Begins the transaction (and turns off auto-committing).
        def begin_db_transaction
          @connection.transaction('READ COMMITTED')
        end

        # Commits the transaction (and turns on auto-committing).
        def commit_db_transaction
          @connection.commit
        end

        # Rolls back the transaction (and turns on auto-committing). Must be
        # done if the transaction block raises an exception or returns false.
        def rollback_db_transaction
          @connection.rollback
        end

        # Appends +LIMIT+ and +OFFSET+ options to an SQL statement, or some SQL
        # fragment that has the same semantics as LIMIT and OFFSET.
        #
        # +options+ must be a Hash which contains a +:limit+ option
        # and an +:offset+ option.
        #
        # This method *modifies* the +sql+ parameter.
        #
        # ===== Examples
        #  add_limit_offset!('SELECT * FROM suppliers', {:limit => 10, :offset => 50})
        # generates
        #  SELECT * FROM suppliers LIMIT 10 OFFSET 50
        def add_limit_offset!(sql, options) # :nodoc:
          if limit = options[:limit]
            if offset = options[:offset]
              sql << " ROWS #{offset.to_i + 1} TO #{offset.to_i + limit.to_i}"
            else
              sql << " ROWS #{limit.to_i}"
            end
          end
          sql
        end

        def default_sequence_name(table_name, _column = nil)
          "#{table_name.to_s.tr('-', '_')[0, table_name_length - 4]}_seq"
        end

        # Set the sequence to the max value of the table's column.
        def reset_sequence!(table, column, sequence = nil)
          sequence ||= default_sequence_name(table, column)
          max_id = select_value("select max(#{column}) from #{table}")
          execute("alter sequence #{sequence} restart with #{max_id}")
        end

        # Uses the raw connection to get the next sequence value.
        def next_sequence_value(sequence_name)
          @connection.query("SELECT NEXT VALUE FOR #{sequence_name} FROM RDB$DATABASE")[0][0]
        end

        protected

        # Returns an array of record hashes with the column names as keys and
        # column values as values. ActiveRecord >= 4 returns an ActiveRecord::Result.
        def select(sql, name = nil, binds = [])
          result = exec_query(sql, name, binds)
          ::ActiveRecord::VERSION::MAJOR > 3 ? result : result.to_a
        end

        # Since the ID is prefetched and passed to #insert, this method is useless.
        # Overriding this method allows us to avoid overriding #insert.
        def last_inserted_id(_result)
          nil
        end
      end
    end
  end
end
