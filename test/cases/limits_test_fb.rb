# encoding: UTF-8
require File.expand_path('../fb_helper', __FILE__)
require 'models_fb/foo'

class LimitsTest < ActiveRecord::TestCase
  def setup
    30.times { |i| Foo.create(:v => i) }
  end

  def teardown
    Foo.delete_all
  end

  def test_select_with_limit
    assert_equal (0..4).to_a, Foo.limit(5).map(&:v)
    assert_equal (0..9).to_a, Foo.limit(10).map(&:v)
    assert_equal (0..29).to_a, Foo.limit(40).map(&:v)
  end

  def test_select_with_offset
    assert_equal (5..29).to_a, Foo.offset(5).map(&:v)
    assert_equal (10..29).to_a, Foo.offset(10).map(&:v)
    assert_equal [], Foo.offset(40).map(&:v)
  end

  def test_select_with_limit_and_offset
    assert_equal (5..9).to_a, Foo.limit(5).offset(5).map(&:v)
    assert_equal (10..19).to_a, Foo.limit(10).offset(10).map(&:v)
    assert_equal (25..29).to_a, Foo.limit(40).offset(25).map(&:v)
  end

  def test_update_with_limit
    assert_equal 1, Foo.where(v: 7).count
    Foo.limit(5).update_all(v: 7)
    assert_equal 6, Foo.where(v: 7).count
    assert_equal [7,7,7,7,7,5,6,7,8,9], Foo.limit(10).map(&:v)
  end
end
