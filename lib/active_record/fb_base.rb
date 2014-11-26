module ActiveRecord
  class Base
    def self.fb_connection(config) # :nodoc:
      config = config.symbolize_keys.reverse_merge(:downcase_names => true)
      fail ArgumentError, 'No database specified. Missing argument: database.' unless config[:database]
      if db_host = config[:host]
        config[:database] = File.expand_path(config[:database]) if db_host =~ /localhost/i
        config[:database].prepend "#{db_host}/#{config[:port] || 3050}:"
      end
      require 'fb'
      db = ::Fb::Database.new(config)
      begin
        connection = db.connect
      rescue
        unless config[:create]
          require 'pp'
          pp config
          raise ConnectionNotEstablished, "No Firebird connections established."
        end
        connection = db.create.connect
      end
      ConnectionAdapters::FbAdapter.new(connection, logger, config)
    end
  end
end
