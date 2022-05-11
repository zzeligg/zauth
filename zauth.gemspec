Gem::Specification.new do |s|
  s.name        = 'zauth'
  s.version     = '0.0.1'
  s.summary     = "Basic authentication routines for Rails"
  s.description = "A simple gem to encapsulate generators for authentication concerns for ActiveRecord and ActionController"
  s.authors     = ["Charles Bedard"]
  s.email       = 'zzeligg@icloud.com'
  s.date        = '2022-05-10'
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/zzeligg/zauth'
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.files = Dir['CHANGELOG', 'MIT_LICENSE', 'README.rdoc', 'lib/**/*']

  s.required_ruby_version = ">= 2.7.0"
  s.add_dependency "actionpack", ">= 7.0.0"
  s.add_dependency "activerecord", ">= 7.0.0"
  s.add_dependency "railties", ">= 7.0.0"
  s.add_dependency "rack"
  s.add_dependency 'rotp'
end