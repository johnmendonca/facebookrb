require 'uri'
require 'net/http'
require 'digest/md5'
require 'yajl'

module FacebookRb
  class FacebookError < RuntimeError
    attr_accessor :fb_code, :fb_message
    def initialize(error_code, error_msg)
      self.fb_code = error_code
      self.fb_message = error_msg
      super("Facebook error #{error_code}: #{error_msg}" )
    end
  end

  class Client
    FB_URL = "http://api.facebook.com/restserver.php"
    FB_API_VERSION = "1.0"
    USER_FIELDS = [:uid, :status, :political, :pic_small, :name, :quotes, 
      :is_app_user, :tv, :profile_update_time, :meeting_sex, :hs_info, 
      :timezone, :relationship_status, :hometown_location, :about_me, 
      :wall_count, :significant_other_id, :pic_big, :music, :work_history, 
      :sex, :religion, :notes_count, :activities, :pic_square, :movies, 
      :has_added_app, :education_history, :birthday, :birthday_date, 
      :first_name, :meeting_for, :last_name, :interests, :current_location, 
      :pic, :books, :affiliations, :locale, :profile_url, :proxied_email, 
      :email_hashes, :allowed_restrictions, :pic_with_logo, :pic_big_with_logo, 
      :pic_small_with_logo, :pic_square_with_logo]
    USER_FIELDS_STANDARD = [:uid, :first_name, :last_name, :name, :timezone, 
      :birthday, :sex, :affiliations, :locale, :profile_url, :proxied_email]

    attr_accessor :api_key, :secret, :session_key, :fb_params
    attr_accessor :last_response

    def initialize(api_key, secret, session_key=nil)
      @api_key = api_key
      @secret = secret
      @session_key = session_key
    end

    def fb_params=(params)
      @fb_params = params
      @session_key = params['session_key'] if params 
    end

    #
    # Call facebook server with a method request. Most keyword arguments
    # are passed directly to the server with a few exceptions.
    #
    # The default return is a parsed json object.
    # Unless the 'format' and/or 'callback' arguments are given,
    # in which case the raw text of the reply is returned. The string
    # will always be returned, even during errors.
    #
    # If an error occurs, a FacebookError exception will be raised
    # with the proper code and message.
    #
    def call(method, params={})
      api_params = params.dup

      # Prepare standard arguments for call
      api_params['method']      ||= method
      api_params['api_key']     ||= api_key
      api_params['session_key'] ||= session_key
      api_params['call_id']     ||= Time.now.to_s
      api_params['v']           ||= FB_API_VERSION
      api_params['format']      ||= 'JSON'

      # Encode any Array or Hash arguments into JSON
      json_encoder = Yajl::Encoder.new
      api_params.each do |key, value|
        if value.is_a?(Array) || value.is_a?(Hash)
          api_params[key] = json_encoder.encode(value)
        end
      end

      api_params['sig'] = generate_signature(api_params, self.secret)

      # Call website with POST request
      response = Net::HTTP.post_form( URI.parse(FB_URL), api_params )

      # Handle response
      self.last_response = response.body
      data = Yajl::Parser.parse(response.body)

      if data.include?('error_msg')
        raise FacebookError.new(data['error_code'], data['error_msg'])
      end

      return data
    end

    def add_special_params(method, params)
      #call_as_apikey for Permissions API
      #ss Session secret
      #use_ssl_resources
    end

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
      return fb_params if signature && valid_signature?(fb_params, signature)
      nil
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
      #Convert any symbol keys to strings
      #otherwise sort() bombs
      fb_params.each_key do |key|
        fb_params[key.to_s] = fb_params.delete(key) if key.is_a?(Symbol)
      end

      str = String.new
      fb_params.sort.each do |key, value|
        str << "#{key.to_s}=#{value}"
      end
      Digest::MD5.hexdigest("#{str}#{secret}")
    end
  end

  # This Rack middleware checks the signature of Facebook params and
  # converts them to Ruby objects when appropiate. Also, it converts
  # the request method from the Facebook POST to the original HTTP
  # method used by the client.
  #
  # == Usage
  #
  # In your rack builder:
  #
  #   use Rack::Facebook, :api_key => "APIKEY", :secret => "SECRET"
  #
  class Middleware    
    def initialize(app, options={})
      @app = app
      @options = options
    end
    
    def call(env)
      request = Rack::Request.new(env)
      
      client = Client.new(@options[:api_key], @options[:secret])

      if fb_params = client.get_valid_fb_params(request.params, 'fb_sig')
        #env["facebook.original_method"] = env["REQUEST_METHOD"]
        #env["REQUEST_METHOD"] = fb_params['request_method']
      else
        fb_params = client.get_valid_fb_params(request.cookies, @options[:api_key])
      end
      client.fb_params = fb_params
      env['facebook.params'] = fb_params
      env['facebook.client'] = client

      return @app.call(env)
    end
  end
end
