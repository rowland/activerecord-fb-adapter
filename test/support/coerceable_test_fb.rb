# This module was graciously "borrowed" from the SQL Server adapter.
# It allows removing methods from any test case.

module ARTest
  module Fb
    module CoerceableTest
      extend ActiveSupport::Concern

      module ClassMethods
        def coerce_tests!(*methods)
          options = methods.extract_options!
          methods.each do |method|
            coerced_test_warning(method, options)
          end
        end

        def coerce_all_tests!(options = {})
          instance_methods(false).each do |method|
            next unless method.to_s =~ /\Atest/
            coerced_test_warning(method, options)
          end
          STDOUT.puts "Info: Coerced all tests: #{self.name}"
        end

        private

        def coerced_test_warning(method, options)
          method = instance_methods(false).select { |m| m =~ method } if method.is_a?(Regexp)
          Array(method).each do |m|
            if m && method_defined?(m)
              next undef_method(m) unless options[:reason]
              define_method(m) { skip options[:reason] }
            else
              STDOUT.puts "Info: Undefined coerced test: #{self.name}##{m}"
            end
          end
        end
      end
    end
  end
end
