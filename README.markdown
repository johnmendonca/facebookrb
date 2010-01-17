= rack-fb 

Rack-fb is currently a work in progress.  It aims to be a lightweight client for the [Facebook API](http://wiki.developers.facebook.com/index.php/API).

Installation
-------------

    gem install rack-fb

General Usage
-------------

The most general case is to use MiniFB.call method:

    user_hash = MiniFB.call(FB_API_KEY, FB_SECRET, "Users.getInfo", "session_key"=>@session_key, "uids"=>@uid, "fields"=>User.all_fields)

Which simply returns the parsed json response from Facebook.

Some Higher Level Objects for Common Uses
----------------------

Get a MiniFB::Session:

    @fb = MiniFB::Session.new(FB_API_KEY, FB_SECRET, @fb_session, @fb_uid)

With the session, you can then get the user information for the session/uid.

    user = @fb.user

Then get info from the user:

    first_name = user["first_name"]

Or profile photos:

    photos = user.profile_photos

Or if you want other photos, try:

    photos = @fb.photos("pids"=>[12343243,920382343,9208348])

Support
--------

Join our Discussion Group at: http://groups.google.com/group/mini_fb

=======
This Rack middleware checks the signature of Facebook params, and
converts them to Ruby objects when appropiate. Also, it converts
the request method from the Facebook POST to the original HTTP
method used by the client.

If the signature is wrong, it returns a "400 Invalid Facebook Signature".

Optionally, it can take a block that receives the Rack environment
and returns a value that evaluates to true when we want the middleware to
be executed for the specific request.

# Usage

In your config.ru:

    require 'rack/facebook'
    use Rack::Facebook, "my_facebook_secret_key"

Using a block condition:

    use Rack::Facebook, "my_facebook_secret_key" do |env|
      env['REQUEST_URI'] =~ /^\/facebook_only/
    end

# Credits

Carlos Paramio

