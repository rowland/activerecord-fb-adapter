module ActiveRecord
  class Base
    def self.fb_connection(config) # :nodoc:
      config = config.symbolize_keys.merge(:downcase_names => true)
      unless config.has_key?(:database)
        raise ArgumentError, "No database specified. Missing argument: database."
      end
      config[:database] = File.expand_path(config[:database]) if config[:host] =~ /localhost/i
      config[:database] = "#{config[:host]}/#{config[:port] || 3050}:#{config[:database]}" if config[:host]
      require 'fb'
      db = Fb::Database.new(config)
      begin
        connection = db.connect
      rescue
        require 'pp'
        pp config unless config[:create]
        connection = config[:create] ? db.create.connect : (raise ConnectionNotEstablished, "No Firebird connections established.")
      end
      ConnectionAdapters::FbAdapter.new(connection, logger, config)
    end
  end
end
