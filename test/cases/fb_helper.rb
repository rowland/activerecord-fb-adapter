# encoding: UTF-8
require 'bundler'
Bundler.require(:default, :development, :test)
require 'support/paths_fb'
require 'support/minitest_fb'
require 'mocha/mini_test'
require 'active_record/connection_adapters/fb_adapter'
require 'active_record/tasks/fb_database_tasks'
require 'support/overrides_fb'

# Reset the db directory
ARTest::Fb.setup_database_dir!

require 'cases/helper'
require 'support/skippable_test_fb'
ActiveRecord::TestCase.send :include, ARTest::Fb::SkippableTest

ARTest::Fb.load_schema!

if defined? Encoding
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end
