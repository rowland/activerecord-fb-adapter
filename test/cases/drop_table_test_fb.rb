# encoding: UTF-8
require 'cases/fb_helper'

class CreateTableTestFb < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
    @raw = @connection.raw_connection
  end

  def teardown
    @connection.drop_table :bicycles rescue nil
  end

  def test_removes_sequence
    @connection.create_table :bicycles
    @connection.drop_table :bicycles
    assert !@raw.generator_names.include?('bicycles_seq')
  end

  def test_removes_custom_sequence
    @connection.create_table :bicycles, sequence: 'other_bicycles_seq'
    @connection.drop_table :bicycles, sequence: 'other_bicycles_seq'
    assert !@raw.generator_names.include?('other_bicycles_seq')
  end
end
