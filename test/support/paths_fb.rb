require 'fileutils'

module ARTest
  module Fb
    extend self

    def root_fb
      File.expand_path File.join(File.dirname(__FILE__), '..', '..')
    end

    def setup_database_dir!
      db_dir = File.join(root_fb, 'db')
      FileUtils.rm_rf db_dir
      FileUtils.mkdir db_dir
      FileUtils.chmod 0777, db_dir
    end

    def load_schema!
      load File.join(test_root_fb, 'schema', 'fb_specific_schema.rb')
    end

    def test_root_fb
      File.join root_fb, 'test'
    end

    def root_activerecord
      Gem.loaded_specs['activerecord'].full_gem_path
    end

    def test_root_activerecord
      File.join root_activerecord, 'test'
    end

    def test_load_paths
      ar_lib = File.join root_activerecord, 'lib'
      ar_test = File.join root_activerecord, 'test'
      ['lib', 'test', ar_lib, ar_test]
    end

    def add_to_load_paths!
      test_load_paths.each { |p| $LOAD_PATH.unshift(p) unless $LOAD_PATH.include?(p) }
    end

    def migrations_root
      File.join test_root_fb, 'migrations'
    end

    def arconfig_file_env!
      ENV['ARCONFIG'] = File.join(test_root_fb, 'config.yml')
    end
  end
end

ARTest::Fb.add_to_load_paths!
ARTest::Fb.arconfig_file_env!
