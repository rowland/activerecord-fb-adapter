require 'minitest-spec-rails'

# Versions before 5.0 don't name the test
module MiniTestSpecRails::DSL::ClassMethods
  def test(name, &block)
    it(name) { self.instance_eval(&block) }
  end
end

require 'minitest-spec-rails/init/active_support'

Minitest::Reporters.use! ENV['TRAVIS'] ?
                         MinitestReporters::DefaultReporter.new(color: false) :
                         Minitest::Reporters::SpecReporter.new
