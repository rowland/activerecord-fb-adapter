module ActiveRecord
  module ConnectionAdapters
    class FbColumn < Column # :nodoc:

      if ActiveRecord::VERSION::STRING < "4.2.0"
        def initialize(name, default, sql_type = nil, null = true, fb_options = {})
          @domain, @sub_type = fb_options.values_at(:domain, :sub_type)
          super(name.downcase, parse_default(default), sql_type, null)
        end
      else
        def initialize(name, default, cast_type, sql_type = nil, null = true, fb_options = {})
          @domain, @sub_type = fb_options.values_at(:domain, :sub_type)
          super(name.downcase, parse_default(default), cast_type, sql_type, null)
        end
      end

      private

      def parse_default(default)
        return if default.nil? || default =~ /null/i
        default.gsub(/^\s*DEFAULT\s+/i, '').gsub(/(^'|'$)/, '')
      end

      def simplified_type(field_type)
        return :boolean if @domain =~ /boolean/i
        return :datetime if field_type =~ /timestamp/i
        return :text if field_type =~ /(binary|blob)/i && @sub_type == 1
        super
      end
    end
  end
end
