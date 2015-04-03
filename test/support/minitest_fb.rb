require 'minitest-spec-rails'

# Versions before 5.0 don't name the test
module MiniTestSpecRails::DSL::ClassMethods
  def test(name, &block)
    it(name) { self.instance_eval(&block) }
  end
end

require 'minitest-spec-rails/init/active_support'

reporter = if ENV['TRAVIS']
  Minitest::Reporters::DefaultReporter.new(color: false)
else
  Minitest::Reporters::SpecReporter.new
end

Minitest::Reporters.use! reporter
