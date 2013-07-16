# $:.unshift File.join(File.dirname(__FILE__),'..')
$:.unshift File.join(File.dirname(__FILE__),'..', 'lib')
require 'rubygems'
require 'test/unit'
require 'active_support'
require 'active_record'
require 'fb'
require 'logger'

config = {
  :adapter => 'fb',
  :database => 'localhost:/var/fbdata/fb_adapter_test.fdb',
  :username => 'sysdba',
  :password => 'masterkey',
  :charset => 'NONE'
}

db = Fb::Database.new(config)
begin
  conn = db.connect
rescue
  conn = db.create.connect
end

conn.close

ActiveRecord::Base.establish_connection(config)

