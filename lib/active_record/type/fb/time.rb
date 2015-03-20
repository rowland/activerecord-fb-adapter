module ActiveRecord
  module Type
    module Fb
      class Time < ::ActiveRecord::Type::Time
        # ActiveRecord's default Time type submits times
        # to the database with dates, which results in
        # char overflow errors. Here, we force the value to
        # a string and remove the date portion.
        def type_cast_for_database(value)
          if value.is_a?(::Time)
            value.to_s(:db).split(' ').last
          else
            super
          end
        end

        def type_cast_for_schema(value)
          "'#{type_cast_for_database(value)}'"
        end
      end
    end
  end
end
