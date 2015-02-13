module ActiveRecord
  class Base
    def self.fb_connection(config) # :nodoc:
      require 'fb'
      config = fb_connection_config(config)
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

    def self.fb_connection_config(config)
      config = config.symbolize_keys.dup.reverse_merge(:downcase_names => true, :port => 3050)
      fail ArgumentError, 'No database specified. Missing argument: database.' if !config[:database]
      if config[:host].nil? || config[:host] =~ /localhost/i
        config[:database] = File.expand_path(config[:database], defined?(Rails) && Rails.root)
      end
      config[:database] = "#{config[:host]}/#{config[:port]}:#{config[:database]}" if config[:host]
      config
    end
  end
end
