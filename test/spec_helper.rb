begin
  require 'rubygems'
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'trellis'

FIXTURES = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures')) unless defined?(FIXTURES)
def require_fixtures(path)
  require File.expand_path(File.join(FIXTURES, path))
end