require 'cases/fb_helper'

class TypesTestFb < ActiveRecord::TestCase
  def test_string
    assert_equal :string, column(:type_string).type
  end

  def test_string_limit
    assert_equal 10, column(:type_string).limit
  end

  def test_smallint
    assert_equal :integer, column(:type_smallint).type
  end

  def test_smallint_limit
    assert_equal 2, column(:type_smallint).limit
  end

  def test_integer
    assert_equal :integer, column(:type_integer).type
  end

  def test_integer_limit
    assert_equal 4, column(:type_integer).limit
  end

  def test_bigint
    assert_equal :integer, column(:type_bigint).type
  end

  def test_bigint_limit
    assert_equal 8, column(:type_bigint).limit
  end

  def test_float
    assert_equal :float, column(:type_float).type
  end

  def test_float_limit
    assert_equal 4, column(:type_float).limit
  end

  def test_double
    assert_equal :float, column(:type_double).type
  end

  def test_double_limit
    assert_equal 8, column(:type_double).limit
  end

  def test_decimal
    assert_equal :decimal, column(:type_decimal).type
  end

  def test_decimal_precision
    assert_equal 10, column(:type_decimal).precision
  end

  def test_decimal_scale
    assert_equal 2, column(:type_decimal).scale
  end

  def test_boolean
    assert_equal :boolean, column(:type_bool).type
  end

  def test_time
    assert_equal :time, column(:type_time).type
  end

  def test_timestamp
    assert_equal :datetime, column(:type_timestamp).type
  end

  def test_datetime
    assert_equal :datetime, column(:type_datetime).type
  end

  def test_date
    assert_equal :date, column(:type_date).type
  end

  def test_blob
    assert_equal :binary, column(:type_binary).type
  end

  def test_text
    assert_equal :text, column(:type_text).type
  end

  if ActiveRecord::VERSION::STRING >= "4.2.0"
    def test_string_cast_type
      type = ActiveRecord::Type::String
      assert_equal type, column(:type_string).cast_type.class
    end

    def test_smallint_cast_type
      type = ActiveRecord::Type::Integer
      assert_equal type, column(:type_smallint).cast_type.class
    end

    def test_integer_cast_type
      type = ActiveRecord::Type::Integer
      assert_equal type, column(:type_integer).cast_type.class
    end

    def test_bigint_cast_type
      type = ActiveRecord::Type::Integer
      assert_equal type, column(:type_bigint).cast_type.class
    end

    def test_float_cast_type
      type = ActiveRecord::Type::Float
      assert_equal type, column(:type_float).cast_type.class
    end

    def test_double_cast_type
      type = ActiveRecord::Type::Float
      assert_equal type, column(:type_double).cast_type.class
    end

    def test_decimal_cast_type
      type = ActiveRecord::Type::Decimal
      assert_equal type, column(:type_decimal).cast_type.class
    end

    def test_boolean_cast_type
      type = ActiveRecord::Type::Boolean
      assert_equal type, column(:type_bool).cast_type.class
    end

    def test_time_cast_type
      type = ActiveRecord::Type::Time
      assert_equal type, column(:type_time).cast_type.class
    end

    def test_timestamp_cast_type
      type = ActiveRecord::Type::DateTime
      assert_equal type, column(:type_timestamp).cast_type.class
    end

    def test_datetime_cast_type
      type = ActiveRecord::Type::DateTime
      assert_equal type, column(:type_datetime).cast_type.class
    end

    def test_date_cast_type
      type = ActiveRecord::Type::Date
      assert_equal type, column(:type_date).cast_type.class
    end

    def test_blob_cast_type
      type = ActiveRecord::Type::Binary
      assert_equal type, column(:type_binary).cast_type.class
    end

    def test_text_cast_type
      type = ActiveRecord::Type::Text
      assert_equal type, column(:type_text).cast_type.class
    end
  end

  private

  def column(name)
    columns = ActiveRecord::Base.connection.columns(:fb_types)
    columns.find { |column| column.name == name.to_s }
  end
end
