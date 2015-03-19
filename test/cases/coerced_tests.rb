# This is where overrides of existing ActiveRecord tests go. It must be loaded after
# AR's tests. Whenever possible, you should broken test here, but if it's something
# that Firebird will never be able to handle, go ahead and undefine it using coerce_tests!
require 'cases/fb_helper'

class ActiveRecord::AdapterTest < ActiveRecord::TestCase
  coerce_tests! :test_disable_referential_integrity,
                reason: "Firebird isn't capable of disabling referential integrity"
end

class BasicsTest < ActiveRecord::TestCase
  # Firebird won't accept quotes in column names
  coerce_tests! :test_column_names_are_escaped
  def test_column_names_are_escaped_coerced
    conn    = ActiveRecord::Base.connection
    badchar = '"'
    quoted  = conn.quote_column_name "foo#{badchar}bar"
    assert_equal("#{badchar}FOOBAR#{badchar}", quoted)
  end
end

class ActiveRecord::Migration::ChangeSchemaTest < ActiveRecord::TestCase
  coerce_tests! :test_add_column_not_null_with_default,
                :test_change_column_quotes_column_names,
                :test_keeping_default_and_notnull_constaint_on_change,
                reason: "Firebird needs to commit DDL changes before insert"
end

class ActiveRecord::Migration::ColumnAttributesTest < ActiveRecord::TestCase
  coerce_tests! :test_native_types, :test_native_decimal_insert_manual_vs_automatic,
                reason: "This test creates columns with precision 30. Firebird only supports up to 18"
end

class MigrationTest < ActiveRecord::TestCase
  coerce_tests! :test_rename_table_with_prefix_and_suffix,
                reason: "Firebird can't rename tables"
end

class ActiveRecord::Migration::RenameTableTest < ActiveRecord::TestCase
  coerce_tests! :test_rename_table, :test_rename_table_with_an_index,
                :test_rename_table_does_not_rename_custom_named_index,
                reason: "Firebird can't rename tables"
end

class TestAdapterWithInvalidConnection < ActiveRecord::TestCase
  def setup
    # This test attempted to use the mysql adapter, which isn't loaded
    Bird.establish_connection adapter: 'fb', database: 'i_do_not_exist'
  end
end
