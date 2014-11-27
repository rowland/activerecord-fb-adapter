module ActiveRecord
  module Tasks # :nodoc:
    class FbDatabaseTasks # :nodoc:
      delegate :fb_connection_config, :establish_connection, to: ::ActiveRecord::Base

      def initialize(configuration, root = ::ActiveRecord::Tasks::DatabaseTasks.root)
        @root, @configuration = root, fb_connection_config(configuration)
      end

      def create
        fb_database.create
        establish_connection configuration
      rescue ::Fb::Error => e
        raise unless e.message.include?('database or file exists')
        raise DatabaseAlreadyExists
      end

      def drop
        fb_database.drop
      rescue ::Fb::Error => e
        raise ::ActiveRecord::ConnectionNotEstablished, e.message
      end

      def purge
        drop
        create
      end

      def structure_dump(filename)
        isql :extract, output: filename
      end

      def structure_load(filename)
        isql input: filename
      end

      private

      def fb_database
        ::Fb::Database.new(configuration)
      end

      # Executes isql commands to load/dump the schema.
      # The generated command might look like this:
      #   isql db/development.fdb -user SYSDBA -password masterkey -extract
      def isql(*args)
        opts = args.extract_options!
        user, pass = configuration.values_at(:username, :password)
        user ||= configuration[:user]
        opts.reverse_merge!(user: user, password: pass)
        cmd = [isql_executable, configuration[:database]]
        cmd += opts.map { |name, val| "-#{name} #{val}" }
        cmd += args.map { |flag| "-#{flag}" }
        cmd = cmd.join(' ')
        raise "Error running: #{cmd}" unless Kernel.system(cmd)
      end

      # Finds the isql command line utility from the PATH
      # Many linux distros call this program isql-fb, instead of isql
      def isql_executable
        require 'mkmf'
        exe = ['isql-fb', 'isql'].detect { |c| find_executable0(c) }
        exe || abort("Unable to find isql or isql-fb in your $PATH")
      end

      def configuration
        @configuration
      end

      def root
        @root
      end
    end
  end
end
