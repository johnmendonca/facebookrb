begin
  require 'yajl/json_gem'
rescue LoadError
  require 'json'
end

require 'digest/md5'

module FacebookRb
  class FacebookError < StandardError
    attr_accessor :code, :message
    def initialize( error_code, error_msg )
      self.code = error_code
      self.message = error_msg
      super("Facebook error #{error_code}: #{error_msg}" )
    end
  end

  class Client
    FB_URL = "http://api.facebook.com/restserver.php"
    FB_API_VERSION = "1.0"

    attr_accessor :api_key, :secret, :fb_params, :session_key
    attr_accessor :results

    def initialize(api_key, secret, fb_params=nil)
      @api_key = api_key
      @secret = secret
      @fb_params = fb_params
      @session_key = fb_params['session_key'] if fb_params
    end

    BAD_JSON_METHODS = ["users.getLoggedInUser","auth.promoteSession"]

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
    def call( method, params )
      api_params = params.dup

      # Prepare standard arguments for call
      api_params["method"]      ||= method
      api_params["api_key"]     ||= api_key
      api_params["session_key"] ||= session_key
      api_params["call_id"]     ||= Time.now.tv_sec.to_s
      api_params["v"]           ||= FB_API_VERSION
      api_params["format"]      ||= "JSON"

      # Encode any Array or Hash arguments into JSON
      api_params.each do |key, value|
        if value.is_a?(Array) || value.is_a?(Hash)
          api_params[key] = JSON.generate(value)
        end
      end

      api_params["sig"] = FacebookRb::generate_signature(api_params, self.secret)

      # Call website with POST request
      begin
        response = Net::HTTP.post_form( URI.parse(FB_URL), api_params )
      rescue SocketError => err
        raise IOError.new( "Cannot connect to the facebook server: " + err )
      end

      # Handle response
      fb_method = api_params["method"]
      body = response.body
      return body

      #begin
      #  data = JSON.parse( body )
      #  if data.include?( "error_msg" ) then
      #    raise FacebookError.new( data["error_code"] || 1, data["error_msg"] )
      #  end
      #rescue JSON::ParserError => ex
      #  if BAD_JSON_METHODS.include?(fb_method) # Little hack because this response isn't valid JSON
      #    return body
      #  else
      #    raise ex
      #  end
      #end
      #return data
    end

    def finalize_params
      #convert arrays to json
    end

    def add_standard_params(method, params)
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
      str = String.new
      fb_params.sort.each do |key, value|
        str << "#{key}=#{value}"
      end
      Digest::MD5.hexdigest("#{str}#{secret}")
    end
  end

  class User
      FIELDS = [:uid, :status, :political, :pic_small, :name, :quotes, :is_app_user, :tv, :profile_update_time, :meeting_sex, :hs_info, :timezone, :relationship_status, :hometown_location, :about_me, :wall_count, :significant_other_id, :pic_big, :music, :work_history, :sex, :religion, :notes_count, :activities, :pic_square, :movies, :has_added_app, :education_history, :birthday, :birthday_date, :first_name, :meeting_for, :last_name, :interests, :current_location, :pic, :books, :affiliations, :locale, :profile_url, :proxied_email, :email_hashes, :allowed_restrictions, :pic_with_logo, :pic_big_with_logo, :pic_small_with_logo, :pic_square_with_logo]
      STANDARD_FIELDS = [:uid, :first_name, :last_name, :name, :timezone, :birthday, :sex, :affiliations, :locale, :profile_url, :proxied_email]

      def self.all_fields
          FIELDS.join(",")
      end

      def self.standard_fields
          STANDARD_FIELDS.join(",")
      end

      def initialize(fb_hash, session)
          @fb_hash = fb_hash
          @session = session
      end

      def [](key)
          @fb_hash[key]
      end

      def uid
          return self["uid"]
      end

      def profile_photos
          @session.photos.get("uid"=>uid, "aid"=>profile_pic_album_id)
      end

      def profile_pic_album_id
          merge_aid(-3, uid)
      end

      def merge_aid(aid, uid)
          uid = uid.to_i
          ret = (uid << 32) + (aid & 0xFFFFFFFF)
          return ret
      end
  end

  class Photos
    def initialize(session)
      @session = session
    end

    def get(params)
      pids = params["pids"]
      if !pids.nil? && pids.is_a?(Array)
        pids = pids.join(",")
        params["pids"] = pids
      end
      @session.call("photos.get", params)
    end
  end

  # Returns the login/add app url for your application.
  #
  # options:
  #    - :next => a relative next page to go to. relative to your facebook connect url or if :canvas is true, then relative to facebook app url
  #    - :canvas => true/false - to say whether this is a canvas app or not
  def self.login_url(api_key, options={})
    login_url = "http://api.facebook.com/login.php?api_key=#{api_key}"
    login_url << "&next=#{options[:next]}" if options[:next]
    login_url << "&canvas" if options[:canvas]
    login_url
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
      if fb_params = FacebookRb::get_valid_fb_params(request.params, 'fb_sig')
        env["facebook.original_method"] = env["REQUEST_METHOD"]
        env["REQUEST_METHOD"] = fb_params['request_method']
      else
        fb_params = FacebookRb::get_valid_fb_params(request.cookies, @options[:api_key])
      end

      env['facebook.client'] = Client.new(@options[:api_key], @options[:secret], fb_params)
      env['facebook.params'] = fb_params

      return @app.call(env)
    end
  end
end
