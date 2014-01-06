require 'rubygems'

def spec
  Gem::Specification.new do |s|
    s.author = "Brent Rowland"
    s.name = "activerecord-fb-adapter"
    s.version = "0.8.2"
    s.date = "2013-12-03"
    s.summary = "ActiveRecord Firebird Adapter for Rails 3 and 4."
    s.summary = "ActiveRecord Firebird Adapter for Rails 3 and 4 with support for migrations."
    s.licenses = ["MIT"]
    s.requirements = "Firebird library fb"
    s.require_path = 'lib'
    s.email = "rowland@rowlandresearch.com"
    s.homepage = "http://github.com/rowland/activerecord-fb-adapter"
    s.has_rdoc = false
    s.files = Dir.glob('lib/active_record/connection_adapters/*')
    s.add_dependency("fb", ">= 0.7.0")
  end
end

if __FILE__ == $0
  Gem::Builder.new(spec).build
end
