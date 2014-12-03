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

  def test_creates_sequence
    @connection.create_table :bicycles
    assert @raw.generator_names.include?('bicycles_seq')
  end

  def test_creates_custom_sequence
    @connection.create_table :bicycles, sequence: 'other_bicycles_seq'
    assert @raw.generator_names.include?('other_bicycles_seq')
  end

  def test_id_false_skips_sequence
    @connection.create_table(:bicycles, id: false) { |t| t.string :name }
    assert !@raw.generator_names.include?('bicycles_seq')
  end

  def test_sequence_false_skip_sequence
    @connection.create_table :bicycles, sequence: false
    assert !@raw.generator_names.include?('bicycles_seq')
  end

  def test_primary_key_table_definition_creates_sequence
    @connection.create_table :bicycles, id: false do |t|
      t.primary_key :other_id
    end
    assert @raw.generator_names.include?('bicycles_seq')
  end

  def test_sequence_false_always_skips_sequence
    @connection.create_table :bicycles, id: false, sequence: false do |t|
      t.primary_key :other_id
    end
    assert !@raw.generator_names.include?('bicycles_seq')
  end
end
