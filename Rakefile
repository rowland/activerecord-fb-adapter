require 'rake'
require 'rake/testtask'

AR_PATH   = Gem.loaded_specs['activerecord'].full_gem_path
AREL_PATH = Gem.loaded_specs['arel'].full_gem_path

# Since the Gemfile for this project requires, rails, it ends up causing
# Rails.env to be defined, which affects some of the unit tests. We fix this
# by setting the RAILS_ENV to "default_env"
ENV['RAILS_ENV'] = 'default_env'

def test_libs
  ['lib', 'test', "#{File.join(AR_PATH, 'test')}", "#{File.join(AREL_PATH, 'test')}"]
end

def test_files
  test_setup = ['test/cases/fb_helper.rb']

  return test_setup + (ENV['TEST_FILES']).split(',') if ENV['TEST_FILES']

  fb_cases      = Dir.glob('test/cases/**/*_test_fb.rb')
  ar_cases      = Dir.glob("#{AR_PATH}/test/cases/**/*_test.rb")
  adapter_cases = Dir.glob("#{AR_PATH}/test/cases/adapters/**/*_test.rb")

  arel_cases = Dir.glob("#{AREL_PATH}/test/**/test_*.rb")

  files = if ENV['FB_ONLY']
            fb_cases
          elsif ENV['ACTIVERECORD_ONLY']
            ar_cases - adapter_cases
          elsif ENV['AREL_ONLY']
            arel_cases
          else
            arel_cases + fb_cases + (ar_cases - adapter_cases)
          end

  return (test_setup + files) unless pattern = ENV.delete('TEST')
  pattern = Regexp.new(pattern)
  test_setup + files.select { |f| f =~ pattern }
end

task default: [:test]

Rake::TestTask.new do |t|
  t.libs = test_libs
  t.test_files = test_files
end
