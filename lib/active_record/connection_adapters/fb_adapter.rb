# Rails 3 & 4 specific database adapter for Firebird (http://firebirdsql.org)
# Author: Brent Rowland <rowland@rowlandresearch.com>
# Based originally on FireRuby extension by Ken Kunz <kennethkunz@gmail.com>

require 'base64'
require 'arel'
require 'arel/visitors/fb'
require 'arel/visitors/bind_visitor'
require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/fb/database_limits'
require 'active_record/connection_adapters/fb/database_statements'
require 'active_record/connection_adapters/fb/quoting'
require 'active_record/connection_adapters/fb/schema_statements'
require 'active_record/connection_adapters/fb_column'
require 'active_record/fb_base'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # The Fb adapter relies on the Fb extension.
    #
    # == Usage Notes
    #
    # === Sequence (Generator) Names
    # The Fb adapter supports the same approach adopted for the Oracle
    # adapter. See ActiveRecord::ModelSchema::ClassMethods#sequence_name= for more details.
    #
    # Note that in general there is no need to create a <tt>BEFORE INSERT</tt>
    # trigger corresponding to a Firebird sequence generator when using
    # ActiveRecord. In other words, you don't have to try to make Firebird
    # simulate an <tt>AUTO_INCREMENT</tt> or +IDENTITY+ column. When saving a
    # new record, ActiveRecord pre-fetches the next sequence value for the table
    # and explicitly includes it in the +INSERT+ statement. (Pre-fetching the
    # next primary key value is the only reliable method for the Fb
    # adapter to report back the +id+ after a successful insert.)
    #
    # === BOOLEAN Domain
    # Firebird 2.5 does not provide a native +BOOLEAN+ type (Only in Firebird 3.x). But you can easily
    # define a +BOOLEAN+ _domain_ for this purpose, e.g.:
    #
    #  CREATE DOMAIN D_BOOLEAN AS SMALLINT CHECK (VALUE IN (0, 1));
    #
    # When the Fb adapter encounters a column that is based on a domain
    # that includes "BOOLEAN" in the domain name, it will attempt to treat
    # the column as a +BOOLEAN+.
    #
    # By default, the Fb adapter will assume that the BOOLEAN domain is
    # defined as above.  This can be modified if needed.  For example, if you
    # have a legacy schema with the following +BOOLEAN+ domain defined:
    #
    #  CREATE DOMAIN BOOLEAN AS CHAR(1) CHECK (VALUE IN ('T', 'F'));
    #
    # ...you can add the following line to your <tt>environment.rb</tt> file:
    #
    #  ActiveRecord::ConnectionAdapters::FbAdapter.boolean_domain = { :true => 'T', :false => 'F', :name => 'BOOLEAN', :type => 'char' }
    #
    # === Column Name Case Semantics
    # Firebird and ActiveRecord have somewhat conflicting case semantics for
    # column names.
    #
    # [*Firebird*]
    #   The standard practice is to use unquoted column names, which can be
    #   thought of as case-insensitive. (In fact, Firebird converts them to
    #   uppercase.) Quoted column names (not typically used) are case-sensitive.
    # [*ActiveRecord*]
    #   Attribute accessors corresponding to column names are case-sensitive.
    #   The defaults for primary key and inheritance columns are lowercase, and
    #   in general, people use lowercase attribute names.
    #
    # In order to map between the differing semantics in a way that conforms
    # to common usage for both Firebird and ActiveRecord, uppercase column names
    # in Firebird are converted to lowercase attribute names in ActiveRecord,
    # and vice-versa. Mixed-case column names retain their case in both
    # directions. Lowercase (quoted) Firebird column names are not supported.
    # This is similar to the solutions adopted by other adapters.
    #
    # In general, the best approach is to use unquoted (case-insensitive) column
    # names in your Firebird DDL (or if you must quote, use uppercase column
    # names). These will correspond to lowercase attributes in ActiveRecord.
    #
    # For example, a Firebird table based on the following DDL:
    #
    #  CREATE TABLE products (
    #    id BIGINT NOT NULL PRIMARY KEY,
    #    "TYPE" VARCHAR(50),
    #    name VARCHAR(255) );
    #
    # ...will correspond to an ActiveRecord model class called +Product+ with
    # the following attributes: +id+, +type+, +name+.
    #
    # ==== Quoting <tt>"TYPE"</tt> and other Firebird reserved words:
    # In ActiveRecord, the default inheritance column name is +type+. The word
    # _type_ is a Firebird reserved word, so it must be quoted in any Firebird
    # SQL statements. Because of the case mapping described above, you should
    # always reference this column using quoted-uppercase syntax
    # (<tt>"TYPE"</tt>) within Firebird DDL or other SQL statements (as in the
    # example above). This holds true for any other Firebird reserved words used
    # as column names as well.
    #
    # === Migrations
    # The Fb adapter currently support Migrations.
    #
    # == Connection Options
    # The following options are supported by the Fb adapter.
    #
    # <tt>:database</tt>::
    #   <i>Required option.</i> Specifies one of: (i) a Firebird database alias;
    #   (ii) the full path of a database file; _or_ (iii) a full Firebird
    #   connection string. <i>Do not specify <tt>:host</tt>, <tt>:service</tt>
    #   or <tt>:port</tt> as separate options when using a full connection
    #   string.</i>
    # <tt>:username</tt>::
    #   Specifies the database user. Defaults to 'sysdba'.
    # <tt>:password</tt>::
    #   Specifies the database password. Defaults to 'masterkey'.
    # <tt>:charset</tt>::
    #   Specifies the character set to be used by the connection. Refer to the
    #   Firebird documentation for valid options.
    class FbAdapter < AbstractAdapter
      include Fb::DatabaseLimits
      include Fb::DatabaseStatements
      include Fb::Quoting
      include Fb::SchemaStatements

      @@boolean_domain = { :true => 1, :false => 0, :name => 'BOOLEAN', :type => 'integer' }
      cattr_accessor :boolean_domain

      class BindSubstitution < Arel::Visitors::Fb # :nodoc:
        include Arel::Visitors::BindVisitor
      end

      def initialize(connection, logger, config=nil)
        super(connection, logger)
        @config = config
        @visitor = Arel::Visitors::Fb.new(self)
      end

      def self.visitor_for(pool) # :nodoc:
        Arel::Visitors::Fb.new(pool)
      end

      # Returns the human-readable name of the adapter.  Use mixed case - one
      # can always use downcase if needed.
      def adapter_name
        'Fb'
      end

      # Does this adapter support migrations?  Backend specific, as the
      # abstract adapter always returns +false+.
      def supports_migrations?
        true
      end

      # Can this adapter determine the primary key for tables not attached
      # to an Active Record class, such as join tables?  Backend specific, as
      # the abstract adapter always returns +false+.
      def supports_primary_key?
        true
      end

      # Does this adapter support using DISTINCT within COUNT?  This is +true+
      # for all adapters except sqlite.
      def supports_count_distinct?
        true
      end

      # Does this adapter support DDL rollbacks in transactions?  That is, would
      # CREATE TABLE or ALTER TABLE get rolled back by a transaction?  PostgreSQL,
      # SQL Server, and others support this.  MySQL and others do not.
      def supports_ddl_transactions?
        false
      end

      # Does this adapter support savepoints? FirebirdSQL does
      def supports_savepoints?
        true
      end

      # Should primary key values be selected from their corresponding
      # sequence before the insert statement?  If true, next_sequence_value
      # is called before each insert to set the record's primary key.
      # This is false for all adapters but Firebird.
      def prefetch_primary_key?(table_name = nil)
        true
      end

      # Does this adapter restrict the number of ids you can use in a list. Oracle has a limit of 1000.
      def ids_in_list_limit
        1499
      end

      # CONNECTION MANAGEMENT ====================================

      # Checks whether the connection to the database is still active. This includes
      # checking whether the database is actually capable of responding, i.e. whether
      # the connection isn't stale.
      def active?
        return false unless @connection.open?
        # return true if @connection.transaction_started
        select("SELECT 1 FROM RDB$DATABASE")
        true
      rescue
        false
      end

      # Disconnects from the database if already connected, and establishes a
      # new connection with the database.
      def reconnect!
        disconnect!
        @connection = ::Fb::Database.connect(@config)
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        super
        @connection.close rescue nil
      end

      # Reset the state of this connection, directing the DBMS to clear
      # transactions and other connection-related server-side state. Usually a
      # database-dependent operation.
      #
      # The default implementation does nothing; the implementation should be
      # overridden by concrete adapters.
      def reset!
        reconnect!
      end

      # Returns true if its required to reload the connection between requests for development mode.
      # This is not the case for FirebirdSQL and it's not necessary for any adapters except SQLite.
      def requires_reloading?
        false
      end

      def create_savepoint(name = current_savepoint_name)
        execute("SAVEPOINT #{name}")
      end

      def rollback_to_savepoint(name = current_savepoint_name)
        execute("ROLLBACK TO SAVEPOINT #{name}")
      end

      def release_savepoint(name = current_savepoint_name)
        execute("RELEASE SAVEPOINT #{name}")
      end

      protected

      if defined?(Encoding)
        def decode(s)
          Base64.decode64(s).force_encoding(@connection.encoding)
        end
      else
        def decode(s)
          Base64.decode64(s)
        end
      end

      def translate(sql)
        sql.gsub!(/\sIN\s+\([^\)]*\)/mi) do |m|
          m.gsub(/\(([^\)]*)\)/m) do |n|
            n.gsub(/\@(.*?)\@/m) do |o|
              "'#{quote_string(decode(o[1..-1]))}'"
            end
          end
        end
        args = []
        sql.gsub!(/\@(.*?)\@/m) { |m| args << decode(m[1..-1]); '?' }
        yield(sql, args) if block_given?
      end

      def expand(sql, args)
        ([sql] + args) * ', '
      end

      def translate_exception(e, message)
        case e.message
        when /violation of FOREIGN KEY constraint/
          InvalidForeignKey.new(message, e)
        when /violation of PRIMARY or UNIQUE KEY constraint/, /attempt to store duplicate value/
          RecordNotUnique.new(message, e)
        else
          super
        end
      end
    end
  end
end
