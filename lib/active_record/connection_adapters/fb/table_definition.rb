module ActiveRecord
  module ConnectionAdapters
    module Fb
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        attr_accessor :needs_sequence

        def primary_key(*args)
          self.needs_sequence = true
          super(*args)
        end
      end
    end
  end
end
