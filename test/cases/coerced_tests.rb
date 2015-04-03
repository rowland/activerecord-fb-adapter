# This is where overrides of existing ActiveRecord tests go. It must be loaded after
# AR's tests. Whenever possible, you should broken test here, but if it's something
# that Firebird will never be able to handle, go ahead and undefine it using skip_tests!
require 'cases/fb_helper'

ARTest::Fb.skip_test! 'ActiveRecord::AdapterTest',
                      :test_disable_referential_integrity,
                      because: "can't disable referential integrity"

ARTest::Fb.coerce 'AttributeMethodsTest' do
  def test_typecast_attribute_from_select_to_false
    Topic.create(:title => 'Budget')
    topic = Topic.all.merge!(:select => "topics.*, 0 as is_test").first
    assert !topic.is_test?
  end

  def test_typecast_attribute_from_select_to_true
    Topic.create(:title => 'Budget')
    topic = Topic.all.merge!(:select => "topics.*, 1 as is_test").first
    assert topic.is_test?
  end
end

ARTest::Fb.coerce 'BasicsTest' do
  skip_tests! :test_limit_with_comma, because: "doesn't support limit with comma"

  # Firebird won't accept quotes in column names
  def test_column_names_are_escaped
    conn    = ActiveRecord::Base.connection
    badchar = '"'
    quoted  = conn.quote_column_name "foo#{badchar}bar"
    assert_equal("#{badchar}FOOBAR#{badchar}", quoted)
  end
end

ARTest::Fb.coerce 'BelongsToAssociationsTest' do
  # Test tries to match firm_with_primary_keys_companies, but we truncate long table names
  def test_belongs_to_with_primary_key_joins_on_correct_column
    sql = Client.joins(:firm_with_primary_key).to_sql
    assert_no_match(/"firm_with_primary_keys_companie"\."id"/i, sql)
    assert_match(/"firm_with_primary_keys_companie"\."name"/i, sql)
  end
end

ARTest::Fb.coerce 'CalculationsTest' do
  # This test tries to match LIMIT
  def test_limit_is_kept
    queries = assert_sql { Account.limit(1).count }
    assert_equal 1, queries.length
    assert_match(/ROWS 1/, queries.first)
  end

  def test_offset_is_kept
    queries = assert_sql { Account.offset(1).count }
    assert_equal 1, queries.length
    assert_match(/SKIP 1/, queries.first)
  end

  def test_limit_with_offset_is_kept
    queries = assert_sql { Account.limit(1).offset(1).count }
    assert_equal 1, queries.length
    assert_match(/ROWS 2 TO 2/, queries.first)
  end
end

ARTest::Fb.skip_tests! 'ActiveRecord::Migration::ChangeSchemaTest',
                       :test_add_column_not_null_with_default,
                       :test_change_column_quotes_column_names,
                       :test_keeping_default_and_notnull_constaint_on_change,
                       :test_keeping_default_and_notnull_constraints_on_change,
                       because: "needs to commit DDL changes before insert"

ARTest::Fb.coerce 'ActiveRecord::Migration::ColumnAttributesTest' do
  skip_tests! :test_add_column_without_limit, because: "doesn't have varchar without limit"

  skip_tests! :test_native_types, :test_native_decimal_insert_manual_vs_automatic,
              because: "Only supports up to precision 18. "\
                       "This test creates columns with precision 30"
end

ARTest::Fb.coerce 'ActiveRecord::Migration::ColumnsTest' do
  # We use non standard index naming
  def test_rename_column_with_an_index
    add_column "test_models", :hat_name, :string
    add_index :test_models, :hat_name

    assert_equal 1, connection.indexes('test_models').size
    rename_column "test_models", "hat_name", "name"

    assert_equal ['test_models_name'], connection.indexes('test_models').map(&:name)
  end

  def test_rename_column_with_multi_column_index
    add_column "test_models", :hat_size, :integer
    add_column "test_models", :hat_style, :string, limit: 100
    add_index "test_models", ["hat_style", "hat_size"], unique: true

    rename_column "test_models", "hat_size", 'size'
    assert_equal ['test_models_hat_style_size'], connection.indexes('test_models').map(&:name)
  end

  def test_remove_column_with_multi_column_index
    add_column "test_models", :hat_size, :integer
    add_column "test_models", :hat_style, :string, :limit => 100
    add_index "test_models", ["hat_style", "hat_size"], :unique => true

    assert_equal 1, connection.indexes('test_models').size
    remove_column("test_models", "hat_size")
    assert_equal [], connection.indexes('test_models').map(&:name)
  end

  def test_column_with_index
    connection.create_table "my_table", force: true do |t|
      t.string :item_number, index: true
    end
    assert connection.index_exists?("my_table", :item_number, name: :my_table_item_number)
  ensure
    connection.drop_table(:my_table) rescue nil
  end
end

ARTest::Fb.skip_test! 'ActiveRecord::Migration::CreateJoinTableTest',
                      :test_create_join_table_with_index,
                      because: 'Index name too long.'

ARTest::Fb.coerce 'DatabaseStatementsTest' do
  # Firebird adapter uses prefetched primary key values
  # from sequence and passes them to connection adapter insert method
  def test_insert_should_return_the_inserted_id
    sequence_name = "accounts_seq"
    id_value = @connection.next_sequence_value(sequence_name)
    sql = "INSERT INTO accounts (id, firm_id,credit_limit) VALUES (?, 42, 5000)"
    id = @connection.insert sql, nil, :id, id_value, sequence_name
    assert_not_nil id
  end
end

ARTest::Fb.coerce 'EagerAssociationTest' do
  skip_test! %r{including association based on sql condition and no database column},
             because: "uses LIMIT instead of FIRST"

  # Firebird offers CHAR_LENGTH(), not LENGTH()
  def test_count_with_include
    assert_equal 3, authors(:david).posts_with_comments
                                   .where("char_length(comments.body) > 15")
                                   .references(:comments).count
  end


  def test_include_has_many_using_primary_key
    expected = Firm.find(1).clients_using_primary_key.sort_by(&:name)
    firm = Firm.all.merge!(
      :includes => :clients_using_primary_key,
      :order => 'clients_using_primary_keys_comp.name'
    ).find(1)
    assert_no_queries do
      assert_equal expected, firm.clients_using_primary_key
    end
  end
end

ARTest::Fb.coerce 'EagerSingularizationTest' do
  self.use_transactional_fixtures = false
end

ARTest::Fb.coerce 'FinderTest' do
  def test_exists_does_not_select_columns_without_alias
    assert_sql(/SELECT 1 AS one FROM TOPICS" ROWS 1/i) do
      Topic.exists?
    end
  end

  def test_take_and_first_and_last_with_integer_should_use_sql_limit
    assert_sql(/ROWS 3/) { Topic.take(3).entries }
    assert_sql(/ROWS 2/) { Topic.first(2).entries }
    assert_sql(/ROWS 5/) { Topic.last(5).entries }
  end
end

ARTest::Fb.coerce 'HasAndBelongsToManyAssociationsTest' do
  # We shorten table names
  def test_join_table_alias
    assert_equal 3, Developer.references(:developers_projects_join).merge(
      :includes => {:projects => :developers},
      :where => 'projects_developers_projects_jo.joined_on IS NOT NULL'
    ).to_a.size
  end

  def test_join_with_group
    group = Developer.columns.inject([]) do |g, c|
      g << "developers.#{c.name}"
      g << "developers_projects_2.#{c.name}"
    end
    Project.columns.each { |c| group << "projects.#{c.name}" }

    assert_equal 3, Developer.references(:developers_projects_join).merge(
      :includes => {:projects => :developers},
      :where => 'projects_developers_projects_jo.joined_on IS NOT NULL',
      :group => group.join(",")
    ).to_a.size
  end
end

ARTest::Fb.coerce 'ActiveRecord::Migration::IndexTest' do
  # This test normally explicitly adds really long index names
  def test_add_index
    connection.add_index("testings", "last_name")
    connection.remove_index("testings", "last_name")

    connection.add_index("testings", ["last_name", "first_name"])
    connection.remove_index("testings", :column => ["last_name", "first_name"])

    connection.add_index("testings", ["last_name", "first_name"])
    connection.remove_index("testings", ["last_name", "first_name"])

    connection.add_index("testings", ["last_name"], :length => 10)
    connection.remove_index("testings", "last_name")

    connection.add_index("testings", ["last_name"], :length => {:last_name => 10})
    connection.remove_index("testings", ["last_name"])

    connection.add_index("testings", ["last_name", "first_name"], :length => 10)
    connection.remove_index("testings", ["last_name", "first_name"])

    connection.add_index("testings", ["last_name", "first_name"], :length => {:last_name => 10, :first_name => 20})
    connection.remove_index("testings", ["last_name", "first_name"])

    connection.add_index("testings", ["key"], :name => "key_idx", :unique => true)
    connection.remove_index("testings", :name => "key_idx", :unique => true)

    connection.add_index("testings", %w(last_name first_name administrator), :name => "named_admin")
    connection.remove_index("testings", :name => "named_admin")
  end
end

ARTest::Fb.skip_all_tests! 'ActiveRecord::ConnectionAdapters::MergeAndResolveDefaultUrlConfigTest',
                           because: "This test doesn't like our manipulation of RAILS_ENV. (not important)"

ARTest::Fb.coerce 'MigrationTest' do
  skip_test! :test_rename_table_with_prefix_and_suffix,
             because: "can't rename tables"

  skip_tests! :test_create_table_with_query,
              :test_create_table_with_query_from_relation,
              because: "can't create tables from a select statement"
end

ARTest::Fb.coerce 'NestedRelationScopingTest' do
  def test_merge_options
    Developer.where('salary = 80000').scoping do
      Developer.limit(10).scoping do
        devs = Developer.all
        sql = devs.to_sql
        assert_match '(salary = 80000)', sql
        assert_match 'ROWS 10', sql
      end
    end
  end
end

ARTest::Fb.coerce 'PersistenceTest' do
  # Value is a reserved word in Firebird
  def test_update_all_with_non_standard_table_name
    assert_equal 1, WarehouseThing.where(id: 1).update_all(['"VALUE" = ?', 0])
    assert_equal 0, WarehouseThing.find(1).value
  end
end

ARTest::Fb.coerce 'ActiveRecord::Migration::ReferencesStatementsTest' do
  skip_tests! :test_creates_polymorphic_index,
              :test_creates_reference_type_column_with_default,
              :test_deletes_polymorphic_index,
              :test_deletes_reference_id_column,
              :test_deletes_reference_id_index,
              :test_deletes_reference_type_column,
              :test_deletes_reference_type_column,
              :test_does_not_delete_reference_type_column,
              because: 'Index too long.'

  # Test uses a really long index name, but explicitly, so it should pass.
  def test_creates_named_index
    add_reference table_name, :tag, index: { name: 'idx_taggings_on_tag_id' }
    assert index_exists?(table_name, :tag_id, name: 'idx_taggings_on_tag_id')
  end
end

ARTest::Fb.skip_tests! 'ActiveRecord::Migration::ReferencesIndexTest',
                       :test_creates_index, :test_creates_index_for_existing_table,
                       :test_creates_index_with_options, :test_creates_polymorphic_index,
                       :test_creates_polymorphic_index_for_existing_table,
                       because: "nonstandard index naming"

ARTest::Fb.skip_tests! 'ActiveRecord::Migration::RenameTableTest',
                       :test_rename_table, :test_rename_table_with_an_index,
                       :test_rename_table_does_not_rename_custom_named_index,
                       because: "can't rename tables"

ARTest::Fb.coerce 'SerializedAttributeTest' do
  # This test was failing because it doesn't insert a pkey
  def test_json_read_db_null
    Topic.serialize :content, JSON
    Topic.connection.insert "INSERT INTO topics (id, content) VALUES(2000, NULL)"
    t = Topic.find(2000)
    assert_nil t.content
  end

  def test_json_read_legacy_null
    Topic.serialize :content, JSON
    Topic.connection.insert "INSERT INTO topics (id, content) VALUES(2000, 'null')"
    t = Topic.find(2000)
    assert_nil t.content
  end
end

ARTest::Fb.coerce 'TestAdapterWithInvalidConnection' do
  def setup; end
  def teardown; end
  skip_tests! %r{inspect on Model class does not raise},
              because: 'This test tries to use MySQL'
end
