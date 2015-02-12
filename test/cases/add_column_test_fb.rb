# encoding: UTF-8
require 'cases/fb_helper'

class AddColumnTestFb < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
    @raw = @connection.raw_connection
    @connection.create_table(:bicycles, id: false) { |t| t.string :name }
  end

  def teardown
    @connection.drop_table :bicycles rescue nil
  end

  def test_primary_key_creates_sequence
    @connection.add_column :bicycles, :id, :primary_key
    assert @raw.generator_names.include?('bicycles_seq')
  end

  def test_primary_key_creates_custom_sequence
    @connection.add_column :bicycles, :id, :primary_key, sequence: 'other_bicycles_seq'
    assert @raw.generator_names.include?('other_bicycles_seq')
  end

  def test_primary_key_with_sequence_false_skips_sequence
    @connection.add_column :bicycles, :id, :primary_key, sequence: false
    assert !@raw.generator_names.include?('bicycles_seq')
  end

  def test_blank_default
    @connection.add_column :bicycles, :model, :string, default: ''
    assert_equal '', @connection.columns('bicycles').find { |column|
      column.name == 'model'
    }.default
  end
end
