# encoding: UTF-8
FB_TEST_ROOT           = File.expand_path(File.join(File.dirname(__FILE__),'..'))
FB_SCHEMA_ROOT         = File.expand_path(File.join(FB_TEST_ROOT,'schema'))
ACTIVERECORD_TEST_ROOT = File.expand_path(File.join(Gem.loaded_specs['activerecord'].full_gem_path,'test'))
AREL_TEST_ROOT         = File.expand_path(File.join(Gem.loaded_specs['arel'].full_gem_path,'test'))
ENV['ARCONFIG']        = File.expand_path(File.join(FB_TEST_ROOT,'config.yml'))

$LOAD_PATH.unshift ACTIVERECORD_TEST_ROOT
$LOAD_PATH.unshift AREL_TEST_ROOT

require 'rubygems'
require 'bundler'
Bundler.setup
require 'mocha/api'
require 'active_support/dependencies'
require 'active_record'
require 'active_record/version'
require 'active_record/connection_adapters/abstract_adapter'
require 'minitest-spec-rails'
require 'minitest-spec-rails/init/active_support'
require 'minitest-spec-rails/init/mini_shoulda'
require 'cases/helper'

if defined?(Encoding)
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly?)

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(File.expand_path(File.join(FB_TEST_ROOT,'debug.log')))
ActiveRecord::Base.logger.level = 0

load File.join(FB_SCHEMA_ROOT, 'fb_specific_schema.rb')
