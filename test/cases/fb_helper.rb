# encoding: UTF-8

FB_ROOT                = File.expand_path('../../..', __FILE__)
FB_TEST_ROOT           = File.join(FB_ROOT, 'test')
FB_SCHEMA_ROOT         = File.join(FB_TEST_ROOT, 'schema')
ACTIVERECORD_TEST_ROOT = File.expand_path(File.join(Gem.loaded_specs['activerecord'].full_gem_path, 'test'))
AREL_TEST_ROOT         = File.expand_path(File.join(Gem.loaded_specs['arel'].full_gem_path, 'test'))
ENV['ARCONFIG']        = File.join(FB_TEST_ROOT, 'config.yml')

$LOAD_PATH.unshift ACTIVERECORD_TEST_ROOT
$LOAD_PATH.unshift AREL_TEST_ROOT

require 'rubygems'
require 'bundler'
require 'fileutils'
Bundler.setup
require 'mocha/api'
require 'active_support/dependencies'
require 'active_record'
require 'active_record/version'
require 'active_record/connection_adapters/abstract_adapter'
require 'minitest-spec-rails'
require 'minitest-spec-rails/init/active_support'
require 'minitest-spec-rails/init/mini_shoulda'
require 'active_record/connection_adapters/fb_adapter'
require 'active_record/tasks/fb_database_tasks'

# Reset the db directory
db_dir = File.join(FB_ROOT, 'db')
FileUtils.rm_rf db_dir
FileUtils.mkdir db_dir
FileUtils.chmod 0777, db_dir

module ActiveRecord::ConnectionAdapters
  # Can't handle decimal precision over 18, so force it as the max
  class TableDefinition
    alias_method :original_column, :column

    def column(name, type, options = {})
      if options[:precision] && options[:precision] > 18
        options[:precision] = 18
      end
      original_column(name, type, options)
    end
  end

  # Set the sequence values 10000 when create_table is called;
  # this prevents primary key collisions between "normally" created records
  # and fixture-based (YAML) records.
  class FbAdapter
    alias_method :original_create_sequence, :create_sequence

    def create_sequence(sequence_name)
      original_create_sequence(sequence_name)
      execute "ALTER SEQUENCE #{sequence_name} RESTART WITH 1000"
    end
  end
end

require 'cases/helper'

if defined?(Encoding)
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly?)

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(File.expand_path(File.join(FB_ROOT, 'debug.log')))
ActiveRecord::Base.logger.level = 0

load File.join(FB_SCHEMA_ROOT, 'fb_specific_schema.rb')
