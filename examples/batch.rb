$:.unshift File.join(File.expand_path(File.dirname(__FILE__)), %w[ .. lib ])

require 'rubygems'
require 'sinatra'
require 'haml'

require 'facebookrb'

use FacebookRb::Middleware, 
  :api_key => 'API_KEY', 
  :secret => 'SECRET'

helpers do
  def fb; env['facebook.client']; end
end

get '/' do
  haml :index, :locals => { :fb_params => fb.params.sort, :params => params.sort }
end

get '/user' do
  results = fb.batch do
    fb.application.getPublicInfo(:application_api_key => fb.api_key)
    fb.users.getInfo(:uids => fb.params['user'], :fields => FacebookRb::Client::USER_FIELDS_STANDARD)
  end
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
