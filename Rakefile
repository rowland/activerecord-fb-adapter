require 'rake'
require 'rake/testtask'
require_relative './test/support/paths_fb'

# Since the Gemfile for this project requires, rails, it ends up causing
# Rails.env to be defined, which affects some of the unit tests. We fix this
# by setting the RAILS_ENV to "default_env"
ENV['RAILS_ENV'] = 'default_env'

task default: [:test]

Rake::TestTask.new do |t|
  t.libs = ARTest::Fb::test_load_paths
  t.test_files = ARTest::Fb.test_files
  t.warning = !!ENV['WARNING']
end
