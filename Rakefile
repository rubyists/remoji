require 'rubygems'
require 'rake'
require 'bundler'
require 'bundler/gem_tasks'

begin
  Bundler.setup(:default, :development, :test)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end

task default: :build
