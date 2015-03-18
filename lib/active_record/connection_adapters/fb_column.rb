module ActiveRecord
  module ConnectionAdapters
    class FbColumn < Column # :nodoc:
      def initialize(name, default, sql_type = nil, null = true, fb_options = {})
        @domain, @sub_type = fb_options.values_at(:domain, :sub_type)
        super(name.downcase, default, sql_type, null)
      end

      def extract_default(default)
        default &&= default.gsub(/^\s*DEFAULT\s+/i, '')
        default &&= default.gsub(/(^'|'$)/, '')
        super default unless default =~ /null/i
      end

      private

      def simplified_type(field_type)
        return :boolean if @domain =~ /boolean/i
        return :datetime if field_type =~ /timestamp/i
        return :text if field_type =~ /(binary|blob)/i && @sub_type == 1
        super
      end
    end
  end
end
