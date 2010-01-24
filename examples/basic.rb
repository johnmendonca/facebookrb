$:.unshift File.join(File.expand_path(File.dirname(__FILE__)), %w[ .. .. lib ])

require 'rubygems'
require 'sinatra'
require 'haml'

require 'facebookrb'

use FacebookRb::Middleware, 
  :api_key => 'API_KEY', 
  :secret => 'SECRET'

get '/' do
  fb_params = env['facebook.client'].params
  haml :index, :locals => { :fb_params => fb_params.sort, :params => params.sort }
end

get '/user' do
  fb = env['facebook.client']
  results = fb.users.getInfo(:uids => fb.params['user'], :fields => FacebookRb::Client::USER_FIELDS)
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
