ENV['RACK_ENV'] = 'test'

require 'rubygems'

require 'rack/fb'

require 'spec'
require 'spec/expectations'
require 'rack/test'

Spec::Runner.configure do |config|
end
