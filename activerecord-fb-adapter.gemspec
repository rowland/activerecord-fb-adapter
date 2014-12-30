Gem::Specification.new do |s|
  s.author = "Brent Rowland"
  s.name = "activerecord-fb-adapter"
  s.version = "0.9.1"
  s.date = "2014-12-30"
  s.summary = "ActiveRecord Firebird Adapter for Rails 3 and 4 with support for migrations."
  s.licenses = ["MIT"]
  s.requirements = "Firebird library fb"
  s.require_path = 'lib'
  s.email = "rowland@rowlandresearch.com"
  s.homepage = "http://github.com/rowland/activerecord-fb-adapter"
  s.has_rdoc = false
  s.files = Dir['README.md', 'lib/**/*']

  s.add_dependency("fb", ">= 0.7.4")
  s.add_dependency('activerecord', '>= 3.2.0')
end
