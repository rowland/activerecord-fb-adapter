# encoding: UTF-8
# $:.unshift File.join(File.dirname(__FILE__),'..')
$:.unshift File.join(File.dirname(__FILE__),'..', 'lib')
require 'rubygems'
require 'test/unit'
require 'active_support'
require 'active_record'
require 'fb'
require 'logger'

if defined?(Encoding)
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

config = {
  :adapter => 'fb',
  :database => 'localhost:/var/fbdata/fb_adapter_test.fdb',
  :username => 'sysdba',
  :password => 'masterkey',
  :charset => 'NONE',
  :encoding => 'UTF-8'
}

db = Fb::Database.new(config)
begin
  conn = db.connect
rescue
  conn = db.create.connect
end

conn.close

ActiveRecord::Base.establish_connection(config)

