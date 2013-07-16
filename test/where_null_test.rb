require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class Bar < ActiveRecord::Base
end

class WhereNullTestCase < Test::Unit::TestCase
  def setup
    # Bar.logger = Logger.new(STDOUT)
    conn = Bar.connection.raw_connection

    conn.execute "DROP TABLE BARS" rescue nil
    conn.execute "CREATE TABLE BARS (ID INT PRIMARY KEY, V1 VARCHAR(255), V2 VARCHAR(255))"
    conn.execute "CREATE GENERATOR BARS_SEQ" rescue nil
    conn.execute "SET GENERATOR BARS_SEQ TO 0"
  end

  def test_update_with_null
    bar = Bar.new(:v1 => "V1", :v2 => "V2")
    bar.save
    assert_not_nil bar.id

    bar.v1 = "Where the Red Fern Grows"
    bar.v2 = nil
    assert bar.save

    Bar.where(:v2 => nil).update_all(:v2 => "worked")
  end
end
