require 'digest/md5'
require 'rack/request'

module Rack
  # This Rack middleware checks the signature of Facebook params and
  # converts them to Ruby objects when appropiate. Also, it converts
  # the request method from the Facebook POST to the original HTTP
  # method used by the client.
  #
  # If the signature is wrong, it returns a "400 Invalid Facebook Signature".
  # 
  # Optionally, it can take a block that receives the Rack environment
  # and returns a value that evaluates to true when we want the middleware to
  # be executed for the specific request.
  #
  # == Usage
  #
  # In your rack builder:
  #
  #   use Rack::Facebook, :api_key => "APIKEY", :secret => "SECRET"
  #
  # == References
  # * http://wiki.developers.facebook.com/index.php/Authorizing_Applications
  # * http://wiki.developers.facebook.com/index.php/Verifying_The_Signature
  #
  class Facebook    
    def initialize(app, options)
      @app = app
      @options = options
    end
    
    def app_name
      @options[:application_name]
    end
    
    def secret
      @options[:secret]
    end
    
    def api_key
      @options[:api_key]
    end
    
    def call(env)
      request = Request.new(env)
      request.api_key = api_key      
      
      if request.facebook?
        valid = true
        
        if request.params_signature
          fb_params = request.extract_facebook_params(:post)
        
          if valid = valid_signature?(fb_params, request.params_signature)
            env["facebook.original_method"] = env["REQUEST_METHOD"]
            env["REQUEST_METHOD"] = fb_params.delete("request_method")
            save_facebook_params(fb_params, env)
          end
        elsif request.cookies_signature
          cookie_params = request.extract_facebook_params(:cookies)
          valid = valid_signature?(cookie_params, request.cookies_signature)
        end
        
        unless valid
          return [400, {"Content-Type" => "text/html"}, ["Invalid Facebook signature"]]
        end
      end
      return @app.call(env)
    end
    
    private
    # Get the signed parameters that were sent from Facebook. Validates the set
    # of parameters against the included signature.
    #
    # Since Facebook sends data to your callback URL via unsecured means, the
    # signature is the only way to make sure that the data actually came from
    # Facebook. So if an app receives a request at the callback URL, it should
    # always verify the signature that comes with against your own secret key.
    # Otherwise, it's possible for someone to spoof a request by
    # pretending to be someone else, i.e.:
    #      www.your-callback-url.com/?fb_user=10101
    #
    # This is done automatically by verify_fb_params.
    #
    # @param  assoc  $params     a full array of external parameters.
    #                            presumed $_GET, $_POST, or $_COOKIE
    # @param  int    $timeout    number of seconds that the args are good for.
    #                            Specifically good for forcing cookies to expire.
    # @param  string $namespace  prefix string for the set of parameters we want
    #                            to verify. i.e., fb_sig or fb_post_sig
    #
    # @return  assoc the subset of parameters containing the given prefix,
    #                and also matching the signature associated with them.
    #          OR    an empty array if the params do not validate
    def get_valid_fb_params(params,  namespace='fb_sig')
      prefix = "#{namespace}_"
      fb_params = Hash.new
      params.each do |key, value|
        if key =~ /^#{prefix}(.*)$/
          fb_params[$1] = value
        end
      end
      
      signature = params[namespace]
      if signature && valid_signature?(fb_params, signature)
        fb_params
      else
        Hash.new
      end
    end

    # Validates that a given set of parameters match their signature.
    # Parameters all match a given input prefix, such as "fb_sig".
    #
    # Parameters:
    #   fb_params     an array of all Facebook-sent parameters, not 
    #                 including the signature itself
    #   expected_sig  the expected result to check against
    #
    def valid_signature?(fb_params, expected_sig)
      expected_sig == generate_signature(fb_params, self.secret)
    end
    
    # Generate a signature using the application secret key.
    #
    # The only two entities that know your secret key are you and Facebook,
    # according to the Terms of Service. Since nobody else can generate
    # the signature, you can rely on it to verify that the information
    # came from Facebook.
    #
    # Parameters:
    #   fb_params   an array of all Facebook-sent parameters, NOT INCLUDING 
    #               the signature itself
    #   secret      your app's secret key
    #
    # Returns:
    #   a md5 hash to be checked against the signature provided by Facebook
    #
    def generate_signature(fb_params, secret)
      str = String.new
      fb_params.sort.each do |key, value|
        str << "#{key}=#{value}"
      end
      Digest::MD5.hexdigest("#{str}#{secret}")
    end
    
    def save_facebook_params(params, env)
      params.each do |key, value|
        ruby_value = case key
        when 'added', 'page_added', 'in_canvas', 'in_profile_tab', 'in_new_facebook', 'position_fix', 'logged_out_facebook'
          value == '1'
        when 'expires', 'profile_update_time', 'time'
          Time.at(value.to_f) rescue TypeError
        when 'friends'
          value.split(',')
        else
          value
        end
            
        env["facebook.#{key}"] = ruby_value
      end
      
      env["facebook.app_name"] = app_name
      env["facebook.api_key"] = api_key
      env["facebook.secret"] = secret
    end
    
    class Request < ::Rack::Request
      FB_PREFIX = "fb_sig".freeze
      attr_accessor :api_key
      
      def facebook?
        params_signature or cookies_signature
      end
      
      def params_signature
        return @params_signature if @params_signature or @params_signature == false
        @params_signature = self.POST.delete(FB_PREFIX) || false
      end

      def cookies_signature
        cookies[@api_key]
      end
      
      def extract_facebook_params(where)
        
        case where
        when :post
          source = self.POST
          prefix = FB_PREFIX
        when :cookies
          source = cookies
          prefix = @api_key
        end
        
        prefix = "#{prefix}_"
        
        source.inject({}) do |extracted, (key, value)|
          if key.index(prefix) == 0
            extracted[key.sub(prefix, '')] = value
            source.delete(key) if :post == where
          end
          extracted
        end
      end
    end
  end
end
