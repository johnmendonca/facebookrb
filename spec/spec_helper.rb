ENV['RACK_ENV'] = 'test'

require 'rubygems'

require File.join(File.dirname(__FILE__), %w{ .. lib rack facebook })

require 'spec'
require 'spec/expectations'
require 'rack/test'

Spec::Runner.configure do |config|
end
