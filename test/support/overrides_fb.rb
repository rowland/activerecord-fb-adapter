module ActiveRecord::ConnectionAdapters
  # Can't handle decimal precision over 18, so force it as the max
  class TableDefinition
    alias_method :original_column, :column

    def column(name, type, options = {})
      if options[:precision] && options[:precision] > 18
        options[:precision] = 18
      end
      original_column(name, type, options)
    end
  end

  # Set the sequence values 10000 when create_table is called;
  # this prevents primary key collisions between "normally" created records
  # and fixture-based (YAML) records.
  class FbAdapter
    alias_method :original_create_sequence, :create_sequence

    def create_sequence(sequence_name)
      original_create_sequence(sequence_name)
      execute "ALTER SEQUENCE #{sequence_name} RESTART WITH 1000"
    end
  end
end
