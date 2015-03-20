module ARTest
  module Fb
    def self.coerce name, &block
      "::#{name}".constantize.class_eval(&block)
    rescue NameError
      STDOUT.puts "Info: #{name} is not defined"
    end

    def skip_all_tests! name, options = {}
      coerce(name) { skip_all_tests! options }
    end

    def skip_tests! name, *test_names
      coerce(name) { skip_tests! *test_names }
    end
    alias_method :skip_test!, :skip_tests!

    module SkippableTest
      extend ActiveSupport::Concern

      module ClassMethods
        def skip_tests!(*methods)
          options = methods.extract_options!
          methods.each do |method|
            do_skip_test(method, options)
          end
        end
        alias_method :skip_test!, :skip_tests!

        def skip_all_tests!(options = {})
          instance_methods(false).each do |method|
            next unless method =~ /\Atest/
            do_skip_test(method, options.merge(log: false))
          end
          STDOUT.puts "Info: Skipped all tests: #{self.name}"
        end

        private

        def do_skip_test(method, options)
          all_tests = instance_methods(false)

          if method.is_a?(Regexp)
            method = all_tests.select { |m| m =~ method }
          end

          Array(method).each do |m|
            if m && method_defined?(m)
              define_method(m) { skip "FIREBIRD: #{options[:because]}" }
              unless options[:log] == false
                STDOUT.puts "Info: Skipped test: #{self.name}##{m}"
              end
            else
              STDOUT.puts "Info: No test found: #{self.name}##{m}"
            end
          end
        end
      end
    end
  end
end
