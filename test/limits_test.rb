# encoding: UTF-8
require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class Foo < ActiveRecord::Base
end

class LimitsTestCase < Test::Unit::TestCase
  def setup
    # Foo.logger = Logger.new(STDOUT)
    conn = Foo.connection.raw_connection

    conn.execute "DROP TABLE FOOS" rescue nil
    conn.execute "CREATE TABLE FOOS (ID INT, V INT)"
    conn.execute "CREATE SEQUENCE FOOS_SEQ" rescue nil
    conn.execute "ALTER SEQUENCE FOOS_SEQ RESTART WITH 0"

    Foo.delete_all
    30.times do |i|
      Foo.create(:v => i)
    end
  end

  def test_select_with_limit
    assert_equal 30, Foo.count
    assert_equal (0..4).to_a, Foo.all(:limit => 5).map(&:v)
    assert_equal (0..9).to_a, Foo.all(:limit => 10).map(&:v)
    assert_equal (0..29).to_a, Foo.all(:limit => 40).map(&:v)
  end

  def test_select_with_limit_and_offset
    assert_equal 30, Foo.count
    assert_equal (5..9).to_a, Foo.all(:limit => 5, :offset => 5).map(&:v)
    assert_equal (10..19).to_a, Foo.all(:limit => 10, :offset => 10).map(&:v)
    assert_equal (25..29).to_a, Foo.all(:limit => 40, :offset => 25).map(&:v)
  end

  def test_update_with_limit
    assert_equal 1, Foo.count(:conditions => "V = 7")
    Foo.update_all("V = 7", nil, :limit => 5)
    assert_equal 6, Foo.count(:conditions => "V = 7")
    assert_equal [7,7,7,7,7,5,6,7,8,9], Foo.all(:limit => 10).map(&:v)
  end
end
