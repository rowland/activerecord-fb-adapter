require 'rake'
require 'rake/testtask'
require_relative './test/support/paths_fb'

# Since the Gemfile for this project requires, rails, it ends up causing
# Rails.env to be defined, which affects some of the unit tests. We fix this
# by setting the RAILS_ENV to "default_env"
ENV['RAILS_ENV'] = 'default_env'

task default: [:test]

FB_HELPER  = 'test/cases/fb_helper.rb'
FB_COERCED = 'test/cases/coerced_tests.rb'

def test_files
  ar_root   = ARTest::Fb.root_activerecord
  fb_cases  = Dir.glob('test/cases/**/*_test_fb.rb')
  ar_cases  = Dir.glob("#{ar_root}/test/cases/**/*_test.rb")
  ar_cases -= Dir.glob("#{ar_root}/test/cases/{tasks,adapters}/**/*_test.rb")

  if ENV['FB_ONLY']
    [FB_HELPER] + fb_cases
  elsif ENV['ACTIVERECORD_ONLY']
    [FB_HELPER] + (ar_cases + [FB_COERCED])
  elsif ENV['TEST_AR']
    names = ENV['TEST_AR'].split(',')
    env_files = names.map { |file| File.join(ar_root, 'test', 'cases', file.strip) }
    [FB_HELPER] + (env_files + [FB_COERCED])
  else
    [FB_HELPER] + fb_cases + (ar_cases + [FB_COERCED])
  end
end

Rake::TestTask.new do |t|
  t.libs = ARTest::Fb::test_load_paths
  t.test_files = test_files
  t.warning = !!ENV['WARNING']
end
