$:.unshift File.join(File.expand_path(File.dirname(__FILE__)), %w[ .. .. lib ])

require 'rubygems'
require 'sinatra'
require 'haml'

require 'facebookrb'

use FacebookRb::Middleware, :api_key => 'b148c9a32f5a8bd089305ca6a52f3214', :secret => '786e1d6080233ef3f302b4f0fc149665'

get '/' do
  fb_params = env['facebook.params'] || {:damn => 'man'}
  haml :index, :locals => { :fb_params => fb_params.sort, :params => params.sort }
end

get '/user' do
  fb_client = env['facebook.client'] || raise('No Facebook Client')
  results = fb_client.call('users.getInfo')
  results.inspect
end

__END__

@@index
%p
  %a{ :href => '/user' } User Info
%h2 Facebook Params
%ul
  - fb_params.each do |pair|
    %li= pair.inspect
%h2 All Params
%ul
  - params.each do |pair|
    %li= pair.inspect

@@user
%h2 User Info
