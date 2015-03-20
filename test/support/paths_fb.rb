require 'fileutils'

module ARTest
  module Fb
    extend self

    TEST_HELPER  = 'test/cases/fb_helper.rb'
    TEST_COERCED = 'test/cases/coerced_tests.rb'

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
      if spec = Gem.loaded_specs['activerecord']
        spec.full_gem_path
      else
        abort "You need to bundle before running the tests. "\
              "You probably want to specify a Rails version as well. "\
              "For example: `export RAILS_VERSION=4.2.0`"
      end
    end

    def test_root_activerecord
      File.join root_activerecord, 'test'
    end

    def test_load_paths
      ar_lib = File.join root_activerecord, 'lib'
      ar_test = File.join root_activerecord, 'test'
      ['lib', 'test', ar_lib, ar_test]
    end

    def test_ar_files
      ar_cases = Dir.glob("#{test_root_activerecord}/cases/**/*_test.rb")
      ignored  = Dir.glob("#{test_root_activerecord}/cases/{tasks,adapters}/**/*_test.rb")
      ar_cases - ignored
    end

    def test_ar_env_files
      ENV['AR_TEST'].split(',').map do |file|
        File.join(test_root_activerecord, 'cases', file.strip)
      end
    end

    def test_ar_smoke_files
      files = %w[ persistence_test.rb associations/eager_test.rb ]
      files.flat_map { |t| Dir.glob("#{test_root_activerecord}/cases/#{t}") }
    end

    def test_fb_files
      Dir.glob('test/cases/**/*_test_fb.rb')
    end

    def test_files
      case
      when ENV['FB_ONLY']           then test_fb_files
      when ENV['ACTIVERECORD_ONLY'] then with_test_files(test_ar_files)
      when ENV['SMOKE']             then with_test_files(test_ar_smoke_files)
      when ENV['AR_TEST']           then with_test_files(test_ar_env_files)
      else
        test_fb_files + with_test_files(test_ar_files)
      end
    end

    def add_to_load_paths!
      test_load_paths.each { |p| $LOAD_PATH.unshift(p) unless $LOAD_PATH.include?(p) }
    end

    def arconfig_file_env!
      ENV['ARCONFIG'] = File.join(test_root_fb, 'config.yml')
    end

    private

    def with_test_files files
      [TEST_HELPER] + (Array(files) + [TEST_COERCED])
    end
  end
end

ARTest::Fb.add_to_load_paths!
ARTest::Fb.arconfig_file_env!
