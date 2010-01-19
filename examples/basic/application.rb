$:.unshift File.join(File.expand_path(File.dirname(__FILE__)), %w[ .. .. lib ])

require 'rubygems'
require 'sinatra'
require 'haml'

require 'facebookrb'

use FacebookRb::Middleware

get '/' do
  fb_params = env['facebook.params'] || {:damn => 'man'}
  haml :index, :locals => { :fb_params => fb_params }
end

__END__

@@index
%ul
  - fb_params.each_pair do |pair|
    %li= pair.inspect
