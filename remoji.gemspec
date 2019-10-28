Gem::Specification.new do |s|
  s.name = 'remoji'
  s.version = '0.0.2'
  s.required_ruby_version = '~> 2'
  s.summary = 'Emojis'
  s.description = 'Search for and show emojis'
  s.authors = ['tj@rubyists.com']
  s.email = 'tj@rubyists.com'
  s.files += Dir.glob('bin/*') + Dir.glob('*.rb') + Dir.glob('*.adoc') + Dir.glob('COPYING')
  s.bindir = 'bin'
  s.executables = ['emj']
  s.add_dependency 'awesome_print', '~> 1.8.0'
  s.add_dependency 'nokogiri', '~> 1'
  s.add_dependency 'rubocop-performance', '~> 1.4'
end
