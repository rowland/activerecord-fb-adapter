# Rails 3 & 4 specific database adapter for Firebird (http://firebirdsql.org)
# Author: Brent Rowland <rowland@rowlandresearch.com>
# Based originally on FireRuby extension by Ken Kunz <kennethkunz@gmail.com>

require 'active_record/connection_adapters/abstract_adapter'
require 'base64'

module Arel
  module Visitors
    class FB < Arel::Visitors::ToSql
    protected

      def visit_Arel_Nodes_SelectStatement o, *a
        select_core = o.cores.map { |x| visit_Arel_Nodes_SelectCore(x, *a) }.join
        select_core.sub!(/^\s*SELECT/i, "SELECT #{visit(o.offset)}") if o.offset && !o.limit
        [
          select_core,
          ("ORDER BY #{o.orders.map { |x| visit(x) }.join(', ')}" unless o.orders.empty?),
          (limit_offset(o) if o.limit && o.offset),
          (visit(o.limit) if o.limit && !o.offset),
        ].compact.join ' '
      end

      def visit_Arel_Nodes_UpdateStatement o, *a
        [
          "UPDATE #{visit o.relation}",
          ("SET #{o.values.map { |value| visit(value) }.join ', '}" unless o.values.empty?),
          ("WHERE #{o.wheres.map { |x| visit(x) }.join ' AND '}" unless o.wheres.empty?),
          (visit(o.limit) if o.limit),
        ].compact.join ' '
      end

      def visit_Arel_Nodes_Limit o, *a
        "ROWS #{visit(o.expr)}"
      end

      def visit_Arel_Nodes_Offset o, *a
        "SKIP #{visit(o.expr)}"
      end

    private
      def limit_offset(o)
        "ROWS #{visit(o.offset.expr) + 1} TO #{visit(o.offset.expr) + visit(o.limit.expr)}"
      end
    end
  end
end

Arel::Visitors::VISITORS['fb'] = Arel::Visitors::FB

module ActiveRecord
  class << Base
    def fb_connection(config) # :nodoc:
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

  module ConnectionAdapters # :nodoc:
    class FbArray < Array
      def column_types
        {}
      end
      
      def columns
        self.any? ? self.first.keys : []
      end
    end

    class FbColumn < Column # :nodoc:
      def initialize(name, domain, type, sub_type, length, precision, scale, default_source, null_flag)
        @firebird_type = Fb::SqlType.from_code(type, sub_type || 0)
        super(name.downcase, nil, @firebird_type, !null_flag)
        @default = parse_default(default_source) if default_source
        case @firebird_type
          when 'VARCHAR', 'CHAR'
            @limit = length
          when 'DECIMAL', 'NUMERIC'
            @precision, @scale = precision, scale.abs
        end
        @domain, @sub_type = domain, sub_type
      end

      def type
        if @domain =~ /BOOLEAN/
          :boolean
        elsif @type == :binary and @sub_type == 1
          :text
        else
          @type
        end
      end

      # Submits a _CAST_ query to the database, casting the default value to the specified SQL type.
      # This enables Firebird to provide an actual value when context variables are used as column
      # defaults (such as CURRENT_TIMESTAMP).
      def default
        if @default
          sql = "SELECT CAST(#{@default} AS #{column_def}) FROM RDB$DATABASE"
          connection = ActiveRecord::Base.connection
          if connection
            value = connection.select_one(sql)['cast']
            if value.acts_like?(:date) or value.acts_like?(:time)
              nil
            else
              type_cast(value)
            end
          else
            raise ConnectionNotEstablished, "No Firebird connections established."
          end
        end
      end

      def self.value_to_boolean(value)
        %W(#{FbAdapter.boolean_domain[:true]} true t 1).include? value.to_s.downcase
      end

    private
      def parse_default(default_source)
        default_source =~ /^\s*DEFAULT\s+(.*)\s*$/i
        return $1 unless $1.upcase == "NULL"
      end

      def column_def
        case @firebird_type
          when 'CHAR', 'VARCHAR'    then "#{@firebird_type}(#{@limit})"
          when 'NUMERIC', 'DECIMAL' then "#{@firebird_type}(#{@precision},#{@scale.abs})"
          #when 'DOUBLE'             then "DOUBLE PRECISION"
          else @firebird_type
        end
      end

      def simplified_type(field_type)
        if field_type == 'TIMESTAMP'
          :datetime
        else
          super
        end
      end
    end

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
      @@boolean_domain = { :true => 1, :false => 0, :name => 'BOOLEAN', :type => 'integer' }
      cattr_accessor :boolean_domain

      def initialize(connection, logger, config=nil)
        super(connection, logger)
        @config = config
        @visitor = Arel::Visitors::FB.new(self)
      end

      def self.visitor_for(pool) # :nodoc:
        Arel::Visitors::FB.new(pool)
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

      # REFERENTIAL INTEGRITY ====================================

      # Override to turn off referential integrity while executing <tt>&block</tt>.
      # def disable_referential_integrity
      #   yield
      # end

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
        @connection = Fb::Database.connect(@config)
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
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

      # Checks whether the connection to the database is still active (i.e. not stale).
      # This is done under the hood by calling <tt>active?</tt>. If the connection
      # is no longer active, then this method will reconnect to the database.
      # def verify!(*ignored)
      #   reconnect! unless active?
      # end

      # Provides access to the underlying database driver for this adapter. For
      # example, this method returns a Mysql object in case of MysqlAdapter,
      # and a PGconn object in case of PostgreSQLAdapter.
      #
      # This is useful for when you need to call a proprietary method such as
      # PostgreSQL's lo_* methods.
      # def raw_connection
      #   @connection
      # end

      # def open_transactions
      #   @open_transactions ||= 0
      # end

      # def increment_open_transactions
      #   @open_transactions ||= 0
      #   @open_transactions += 1
      # end

      # def decrement_open_transactions
      #   @open_transactions -= 1
      # end

      # def transaction_joinable=(joinable)
      #   @transaction_joinable = joinable
      # end

      def create_savepoint
        execute("SAVEPOINT #{current_savepoint_name}")
      end

      def rollback_to_savepoint
        execute("ROLLBACK TO SAVEPOINT #{current_savepoint_name}")
      end

      def release_savepoint
        execute("RELEASE SAVEPOINT #{current_savepoint_name}")
      end

      # def current_savepoint_name
      #   "active_record_#{open_transactions}"
      # end

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
          m.gsub(/\(([^\)]*)\)/m) { |n| n.gsub(/\@(.*?)\@/m) { |n| "'#{quote_string(decode(n[1..-1]))}'" } }
        end
        args = []
        sql.gsub!(/\@(.*?)\@/m) { |m| args << decode(m[1..-1]); '?' }
        yield(sql, args) if block_given?
      end

      def expand(sql, args)
        ([sql] + args) * ', '
      end

      # def log(sql, args, name, &block)
      #   super(expand(sql, args), name, &block)
      # end

      def translate_exception(e, message)
        case e.message
        when /violation of FOREIGN KEY constraint/
          InvalidForeignKey.new(message, e)
        when /violation of PRIMARY or UNIQUE KEY constraint/
          RecordNotUnique.new(message, e)
        else
          super
        end
      end

    public
      # from module Quoting
      def quote(value, column = nil)
        # records are quoted as their primary key
        return value.quoted_id if value.respond_to?(:quoted_id)

        case value
        when String, ActiveSupport::Multibyte::Chars
          value = value.to_s
          if column && [:integer, :float].include?(column.type)
            value = column.type == :integer ? value.to_i : value.to_f
            value.to_s
          elsif column && column.type != :binary && value.size < 256 && !value.include?('@')
            "'#{quote_string(value)}'"
          else
            "@#{Base64.encode64(value).chop}@"
          end
        when NilClass              then "NULL"
        when TrueClass             then (column && column.type == :integer ? '1' : quoted_true)
        when FalseClass            then (column && column.type == :integer ? '0' : quoted_false)
        when Float, Fixnum, Bignum then value.to_s
        # BigDecimals need to be output in a non-normalized form and quoted.
        when BigDecimal            then value.to_s('F')
        when Symbol                then "'#{quote_string(value.to_s)}'"
        else
          if value.acts_like?(:date)
            quote_date(value)
          elsif value.acts_like?(:time)
            quote_timestamp(value)
          else
            quote_object(value)
          end
        end
      end

      def quote_date(value)
        "@#{Base64.encode64(value.strftime('%Y-%m-%d')).chop}@"
      end

      def quote_timestamp(value)
        zone_conversion_method = ActiveRecord::Base.default_timezone == :utc ? :getutc : :getlocal
        value = value.respond_to?(zone_conversion_method) ? value.send(zone_conversion_method) : value
        "@#{Base64.encode64(value.strftime('%Y-%m-%d %H:%M:%S')).chop}@"
      end

      def quote_string(string) # :nodoc:
        string.gsub(/'/, "''")
      end

      def quote_object(obj)
        if obj.respond_to?(:to_str)
          "@#{Base64.encode64(obj.to_str).chop}@"
        else
          "@#{Base64.encode64(obj.to_yaml).chop}@"
        end
      end

      def quote_column_name(column_name) # :nodoc:
        %Q("#{ar_to_fb_case(column_name.to_s)}")
      end

      def quote_table_name_for_assignment(table, attr)
        quote_column_name(attr)
      end if ::ActiveRecord::VERSION::MAJOR >= 4

      # Quotes the table name. Defaults to column name quoting.
      # def quote_table_name(table_name)
      #   quote_column_name(table_name)
      # end

      def quoted_true # :nodoc:
        quote(boolean_domain[:true])
      end

      def quoted_false # :nodoc:
        quote(boolean_domain[:false])
      end

      def type_cast(value, column)
        return super unless value == true || value == false

        value ? quoted_true : quoted_false
      end

    private
      # Maps uppercase Firebird column names to lowercase for ActiveRecord;
      # mixed-case columns retain their original case.
      def fb_to_ar_case(column_name)
        column_name =~ /[[:lower:]]/ ? column_name : column_name.downcase
      end

      # Maps lowercase ActiveRecord column names to uppercase for Fierbird;
      # mixed-case columns retain their original case.
      def ar_to_fb_case(column_name)
        column_name =~ /[[:upper:]]/ ? column_name : column_name.upcase
      end

    public
      # from module DatabaseStatements

      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      # def select_all(sql, name = nil, format = :hash) # :nodoc:
      #   translate(sql) do |sql, args|
      #     log(sql, args, name) do
      #       @connection.query(format, sql, *args)
      #     end
      #   end
      # end
      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      def select_all(arel, name = nil, binds = [])
        add_column_types(select(to_sql(arel, binds), name, binds))
      end

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(sql, name = nil)
        log(sql, name) do
          @connection.query(:array, sql)
        end
      end

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil, skip_logging = false)
        translate(sql) do |sql, args|
          if (name == :skip_logging) or skip_logging
            @connection.execute(sql, *args)
          else
            log(sql, args, name) do
              @connection.execute(sql, *args)
            end
          end
        end
      end

      # Executes +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_query(sql, name = 'SQL', binds = [])
        translate(sql) do |sql, args|
          unless binds.empty?
            args = binds.map { |col, val| type_cast(val, col) } + args
          end
          log(expand(sql, args), name) do
            result, rows = @connection.execute(sql, *args) { |cursor| [cursor.fields, cursor.fetchall] }
            if result.respond_to?(:map)
              cols = result.map { |col| col.name } 
              ActiveRecord::Result.new(cols, rows)
            else
              result
            end
          end
        end
      end

      def explain(arel, binds = [])
        to_sql(arel, binds)
      end

      # Returns the last auto-generated ID from the affected table.
      def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
        sql, binds = sql_for_insert(to_sql(arel, binds), pk, id_value, sequence_name, binds)
        value      = exec_insert(sql, name, binds)
        id_value
      end

      # Executes the update statement and returns the number of rows affected.
      # alias_method :update, :execute
      # def update(sql, name = nil)
      #   update_sql(sql, name)
      # end

      # Executes the delete statement and returns the number of rows affected.
      # alias_method :delete, :execute
      # def delete(sql, name = nil)
      #   delete_sql(sql, name)
      # end

      # Checks whether there is currently no transaction active. This is done
      # by querying the database driver, and does not use the transaction
      # house-keeping information recorded by #increment_open_transactions and
      # friends.
      #
      # Returns true if there is no transaction active, false if there is a
      # transaction active, and nil if this information is unknown.
      def outside_transaction?
        !@connection.transaction_started
      end

      # Begins the transaction (and turns off auto-committing).
      def begin_db_transaction
        @transaction = @connection.transaction('READ COMMITTED')
      end

      # Commits the transaction (and turns on auto-committing).
      def commit_db_transaction
        @transaction = @connection.commit
      end

      # Rolls back the transaction (and turns on auto-committing). Must be
      # done if the transaction block raises an exception or returns false.
      def rollback_db_transaction
        @transaction = @connection.rollback
      end

      # Appends +LIMIT+ and +OFFSET+ options to an SQL statement, or some SQL
      # fragment that has the same semantics as LIMIT and OFFSET.
      #
      # +options+ must be a Hash which contains a +:limit+ option
      # and an +:offset+ option.
      #
      # This method *modifies* the +sql+ parameter.
      #
      # ===== Examples
      #  add_limit_offset!('SELECT * FROM suppliers', {:limit => 10, :offset => 50})
      # generates
      #  SELECT * FROM suppliers LIMIT 10 OFFSET 50
      def add_limit_offset!(sql, options) # :nodoc:
        if limit = options[:limit]
          if offset = options[:offset]
            sql << " ROWS #{offset.to_i + 1} TO #{offset.to_i + limit.to_i}"
          else
            sql << " ROWS #{limit.to_i}"
          end
        end
        sql
      end
      
      def default_sequence_name(table_name, column = nil)
        "#{table_name.to_s[0, table_name_length - 4]}_seq"
      end

      # Set the sequence to the max value of the table's column.
      def reset_sequence!(table, column, sequence = nil)
        max_id = select_value("select max(#{column}) from #{table}")
        execute("alter sequence #{default_sequence_name(table, column)} restart with #{max_id}")
      end

      def next_sequence_value(sequence_name)
        select_one("SELECT NEXT VALUE FOR #{sequence_name} FROM RDB$DATABASE").values.first
      end

      # Inserts the given fixture into the table. Overridden in adapters that require
      # something beyond a simple insert (eg. Oracle).
      # def insert_fixture(fixture, table_name)
      #   execute "INSERT INTO #{quote_table_name(table_name)} (#{fixture.key_list}) VALUES (#{fixture.value_list})", 'Fixture Insert'
      # end

      # def empty_insert_statement_value
      #   "VALUES(DEFAULT)"
      # end

      # def case_sensitive_equality_operator
      #   "="
      # end

    protected
      # add column_types method returns empty hash, requred for rails 4 compatibility
      def add_column_types obj
        FbArray.new(obj)
      end

      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      def select(sql, name = nil, binds = [])
        translate(sql) do |sql, args|
          unless binds.empty?
            args = binds.map { |col, val| type_cast(val, col) } + args
          end
          log(expand(sql, args), name) do
            @connection.query(:hash, sql, *args)
          end
        end
      end

    public
      # from module SchemaStatements

      # Returns a Hash of mappings from the abstract data types to the native
      # database types.  See TableDefinition#column for details on the recognized
      # abstract data types.
      def native_database_types
        {
          :primary_key => "integer not null primary key",
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "blob sub_type text" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "timestamp" },
          :timestamp   => { :name => "timestamp" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => boolean_domain[:name] }
        }
      end

      # Truncates a table alias according to the limits of the current adapter.
      # def table_alias_for(table_name)
      #   table_name[0..table_alias_length-1].gsub(/\./, '_')
      # end

      # def tables(name = nil) end
      def tables(name = nil)
        @connection.table_names
      end

      # Returns an array of indexes for the given table.
      def indexes(table_name, name = nil)
        result = @connection.indexes.values.select {|ix| ix.table_name == table_name && ix.index_name !~ /^rdb\$/ }
        indexes = result.map {|ix| IndexDefinition.new(table_name, ix.index_name, ix.unique, ix.columns) }
        indexes
      end

      def primary_key(table_name) #:nodoc:
        sql = <<-END_SQL
          SELECT s.rdb$field_name
          FROM rdb$indices i
          JOIN rdb$index_segments s ON i.rdb$index_name = s.rdb$index_name
          LEFT JOIN rdb$relation_constraints c ON i.rdb$index_name = c.rdb$index_name
          WHERE i.rdb$relation_name = '#{ar_to_fb_case(table_name)}' and c.rdb$constraint_type = 'PRIMARY KEY';
        END_SQL
        row = select_one(sql)
        row && fb_to_ar_case(row.values.first.rstrip)
      end

      # Returns an array of Column objects for the table specified by +table_name+.
      # See the concrete implementation for details on the expected parameter values.
      def columns(table_name, name = nil)
        sql = <<-END_SQL
          SELECT r.rdb$field_name, r.rdb$field_source, f.rdb$field_type, f.rdb$field_sub_type,
                 f.rdb$field_length, f.rdb$field_precision, f.rdb$field_scale,
                 COALESCE(r.rdb$default_source, f.rdb$default_source) rdb$default_source,
                 COALESCE(r.rdb$null_flag, f.rdb$null_flag) rdb$null_flag
          FROM rdb$relation_fields r
          JOIN rdb$fields f ON r.rdb$field_source = f.rdb$field_name
          WHERE r.rdb$relation_name = '#{ar_to_fb_case(table_name)}'
          ORDER BY r.rdb$field_position
        END_SQL
        select_rows(sql, name).collect do |field|
          field_values = field.collect do |value|
            case value
              when String then value.rstrip
              else value
            end
          end
          FbColumn.new(*field_values)
        end
      end

      def create_table(name, options = {}) # :nodoc:
        begin
          super
        rescue
          raise unless non_existent_domain_error?
          create_boolean_domain
          super
        end
        unless options[:id] == false or options[:sequence] == false
          sequence_name = options[:sequence] || default_sequence_name(name)
          create_sequence(sequence_name)
        end
      end

      def drop_table(name, options = {}) # :nodoc:
        super(name)
        unless options[:sequence] == false
          sequence_name = options[:sequence] || default_sequence_name(name)
          drop_sequence(sequence_name) if sequence_exists?(sequence_name)
        end
      end

      # Adds a new column to the named table.
      # See TableDefinition#column for details of the options you can use.
      def add_column(table_name, column_name, type, options = {})
        add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(add_column_sql, options)
        begin
          execute(add_column_sql)
        rescue
          raise unless non_existent_domain_error?
          create_boolean_domain
          execute(add_column_sql)
        end
        if options[:position]
          # position is 1-based but add 1 to skip id column
          alter_position_sql = "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} POSITION #{options[:position] + 1}"
          execute(alter_position_sql)
        end
      end

      # Changes the column's definition according to the new options.
      # See TableDefinition#column for details of the options you can use.
      # ===== Examples
      #  change_column(:suppliers, :name, :string, :limit => 80)
      #  change_column(:accounts, :description, :text)
      def change_column(table_name, column_name, type, options = {})
        sql = "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} TYPE #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(sql, options)
        execute(sql)
      end

      # Sets a new default value for a column.  If you want to set the default
      # value to +NULL+, you are out of luck.  You need to
      # DatabaseStatements#execute the appropriate SQL statement yourself.
      # ===== Examples
      #  change_column_default(:suppliers, :qualification, 'new')
      #  change_column_default(:accounts, :authorized, 1)
      def change_column_default(table_name, column_name, default)
        execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} SET DEFAULT #{quote(default)}")
      end

      # Renames a column.
      # ===== Example
      #  rename_column(:suppliers, :description, :name)
      def rename_column(table_name, column_name, new_column_name)
        execute "ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
      end

      def remove_index!(table_name, index_name) #:nodoc:
        execute("DROP INDEX #{quote_column_name(index_name)}")
      end

      def index_name(table_name, options) #:nodoc:
        if Hash === options # legacy support
          if options[:column]
            "#{table_name}_#{Array.wrap(options[:column]) * '_'}"
          elsif options[:name]
            options[:name]
          else
            raise ArgumentError, "You must specify the index name"
          end
        else
          index_name(table_name, :column => options)
        end
      end

      def type_to_sql(type, limit = nil, precision = nil, scale = nil)
        case type
        when :integer then integer_to_sql(limit)
        when :float then float_to_sql(limit)
        else super
        end
      end

    private
      # Map logical Rails types to Firebird-specific data types.
      def integer_to_sql(limit)
        return 'integer' if limit.nil?
        case limit
          when 1..2 then 'smallint'
          when 3..4 then 'integer'
          when 5..8 then 'bigint'
          else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a NUMERIC with PRECISION 0 instead.")
        end
      end

      def float_to_sql(limit)
        if limit.nil? || limit <= 4
          'float'
        else
          'double precision'
        end
      end

      def non_existent_domain_error?
        $!.message =~ /Specified domain or source column \w+ does not exist/
      end

      def create_boolean_domain
        sql = <<-end_sql
          CREATE DOMAIN #{boolean_domain[:name]} AS #{boolean_domain[:type]}
          CHECK (VALUE IN (#{quoted_true}, #{quoted_false}) OR VALUE IS NULL)
        end_sql
        execute(sql)
      end

      def create_sequence(sequence_name)
        execute("CREATE SEQUENCE #{sequence_name}")
      end

      def drop_sequence(sequence_name)
        execute("DROP SEQUENCE #{sequence_name}")
      end

      def sequence_exists?(sequence_name)
        @connection.generator_names.include?(sequence_name)
      end

    public
      # from module DatabaseLimits

      # the maximum length of a table alias
      def table_alias_length
        31
      end

      # the maximum length of a column name
      def column_name_length
        31
      end

      # the maximum length of a table name
      def table_name_length
        31
      end

      # the maximum length of an index name
      def index_name_length
        31
      end

      # the maximum number of columns per table
      # def columns_per_table
      #   1024
      # end

      # the maximum number of indexes per table
      def indexes_per_table
        65_535
      end

      # the maximum number of columns in a multicolumn index
      # def columns_per_multicolumn_index
      #   16
      # end

      # the maximum number of elements in an IN (x,y,z) clause
      def in_clause_length
        1499
      end

      # the maximum length of an SQL query
      def sql_query_length
        32767
      end

      # maximum number of joins in a single query
      # def joins_per_query
      #   256
      # end

    end
  end
end
