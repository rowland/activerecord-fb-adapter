module ActiveRecord
  module ConnectionAdapters
    module Fb
      module DatabaseLimits
        # the maximum length of a table alias
        def table_alias_length
          31
        end

        # the maximum length of a column name
        def column_name_length
          31
        end

        # the maximum length of a table name
        def table_name_length
          31
        end

        # the maximum length of an index name
        def index_name_length
          31
        end

        # the maximum number of columns per table
        # def columns_per_table
        #   1024
        # end

        # the maximum number of indexes per table
        def indexes_per_table
          65_535
        end

        # the maximum number of columns in a multicolumn index
        # def columns_per_multicolumn_index
        #   16
        # end

        # the maximum number of elements in an IN (x,y,z) clause
        def in_clause_length
          1499
        end

        # the maximum length of an SQL query
        def sql_query_length
          32767
        end

        # maximum number of joins in a single query
        # def joins_per_query
        #   256
        # end
      end
    end
  end
end
