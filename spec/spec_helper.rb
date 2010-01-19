ENV['RACK_ENV'] = 'test'

require 'rubygems'

require 'facebookrb'

require 'spec'
require 'spec/expectations'
require 'rack/test'

Spec::Runner.configure do |config|
end
