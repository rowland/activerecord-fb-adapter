require 'rubygems'

def spec
  Gem::Specification.new do |s|
    s.author = "Brent Rowland"
    s.name = "activerecord-fb-adapter"
    s.version = "0.7.2"
    s.date = "2012-09-18"
    s.summary = "ActiveRecord Firebird Adapter for Rails 3"
    s.summary = "ActiveRecord Firebird Adapter for Rails 3. Unlike fb_adapter for Rails 1.x and 2.x, this version attempts to support migrations."
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
