# ActiveRecord Firebird Adapter

<img src="/project_logo.png" align="left" hspace="10">
This is the ActiveRecord adapter for working with the [Firebird SQL Server](http://firebirdsql.org/). It currently supports Rails 3.2.x and 4.x. Although this adapter may not yet have feature parity with the 1st tier databases supported by Rails, it has been used in production by different people for several months without issues and may be considered stable. It uses under the hood the [Ruby Firebird Extension Library](https://github.com/rowland/fb).

## What's supported

- Datatypes: string, integer, datetime, boolean, float, decimal, text (blob).
- Rails migrations and db/schema.rb generation.
- Linux and Windows supported (OS X somebody?).

## Getting started

1) Install and start the Firebird Server in your machine (varies across operating systems).

2) Create a new Rails project.

```
rails new firebird_test
cd firebird_test
```

3) Edit the project Gemfile and add the **activerecord-fb-adapter** gem:

```ruby
source 'https://rubygems.org'

gem 'activerecord-fb-adapter'

(...)
```

Then run:

```
bundle update
```

which will make bundler to get the gem with it's only dependency: the Fb gem which is "native" (has C code) and will be compiled the first time. Be sure you have a Firebird installation with access to the "INTERBASE.H" file for this to succeed.

4) Edit the **database.yml** for configuring your database connection:

```ruby
development:
  adapter: fb
  database: db/development.fdb
  username: SYSDBA
  password: masterkey
  host: localhost
  encoding: UTF-8
  create: true
```

The default Firebird administrator username and password are **SYSDBA** and **masterkey**, you may have to adjust this to your installation.

Currently the adapter does not supports the "rake db:create" task, so in order to create the database you must add the "create: true" option; with this switch the first time the adapter tries to connect to the database it will be created if it doesn't exists.

5) Start the rails server in development mode

```
bundle exec rails server
```

Open your browser at http://localhost:3000, this will create the database on the first connection.

On Linux you may get:

```
Fb::Error (Unsuccessful execution caused by a system error that precludes successful execution of subsequent statements
I/O error during "open O_CREAT" operation for file "db/development.fdb"
Error while trying to create file
Permission denied
```

This is because, by default, the Firebird Server runs under the "firebird" user and group, which has no write access to the "db" folder of the project. To fix it run:

```
chmod o+w db
```
which will add write permission to "others" group.

6) Now you can start generating scaffolds or models and rails will create the corresponding migrations. Use **bundle exec rake db:migrate** and **bundle exec rake db:rollback** for migrating the database; this will update your **db/schema.rb** file automatically.

## Changelog

#### 0.8.2
- Fix "singleton can't be dumped" marshaling error.

#### 0.8.1
- Set limit for CHAR types, but no longer needed for BLOBs.
- Fix columns parameters only set when needed in FbColumn#initialize.
- Added position option to add_column migration:

```ruby
add_column :table_name, :column_name, :data_type, { position: 3 }
```
#### 0.8.0
- Rails 4.x support.

## License
It is free software, and may be redistributed under the terms specified in the MIT-LICENSE file.
