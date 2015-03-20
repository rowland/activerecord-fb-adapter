# encoding: UTF-8
require 'cases/fb_helper'
require 'models_fb/bar'

class WhereTestFb < ActiveRecord::TestCase
  def test_update_with_null
    bar = Bar.new(:v1 => "V1", :v2 => "V2")
    bar.save
    refute_nil bar.id

    bar.v1 = "Where the Red Fern Grows"
    bar.v2 = nil
    assert bar.save

    Bar.where(:v2 => nil).update_all(:v2 => "worked")
  end

  def test_update_with_utf8_and_encoded_param
    # Not meaningful without Bar.logger commented in above in setup.
    bar = Bar.new(:v1 => "V1", :v2 => "V2ø")
    bar.save
    refute_nil bar.id

    bar.v1 = "Where the Red Fern Grøws"
    bar.v2 = nil
    bar.v3 = "miegebielle.stéphane@orange.fr"
    assert bar.save

    Bar.where(:v2 => nil).update_all(:v2 => "worked")
  end

  def test_where_with_time_on_date_field
    bar = Bar.create(created_date: Date.today)
    result = Bar.where('created_date > ?', 2.days.ago)
    assert_equal bar, result.to_a.first
  end
end
