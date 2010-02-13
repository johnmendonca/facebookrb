require 'rack/request' unless defined?(Rack::Request)
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
    FB_VIDEO_URL = "http://api-video.facebook.com/restserver.php"
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

    attr_accessor :api_key, :secret, :canvas_url, :format
    attr_accessor :pending_batch, :batch_queue, :last_response

    def initialize(options = {})
      self.api_key = options[:api_key] || options['api_key']
      self.secret = options[:secret] || options['secret']
      self.canvas_url = options[:canvas_url] || options['canvas_url']
      self.format = options[:format] || options['format'] || 'JSON'

      def photos.upload(filename, opts); @obj.call_upload "photos.upload", filename, opts end
      def video.upload(filename, opts); @obj.call_upload "video.upload", filename, opts end
    end

    def params
      @params ||= {}
    end

    def [](key)
      params[key]
    end

    def valid?
      !params.empty?
    end

    def url(path = nil)
      path ? "#{canvas_url}#{path}" : canvas_url
    end

    def addurl
      "http://apps.facebook.com/add.php?api_key=#{self.api_key}"
    end

    #
    # Call facebook server with a method request. Most keyword arguments
    # are passed directly to the server with a few exceptions.
    #
    # Returns a parsed json object.
    #
    # If an error occurs, a FacebookError exception will be raised
    # with the proper code and message.
    #
    def call(method, params={})
      api_params = params.dup

      # Prepare standard arguments for call
      api_params['method']      ||= method
      api_params['api_key']     ||= self.api_key
      api_params['format']      ||= self.format
      api_params['session_key'] ||= self.params['session_key']
      api_params['call_id']     ||= Time.now.to_f.to_s
      api_params['v']           ||= FB_API_VERSION

      convert_outgoing_params(api_params)

      api_params['sig'] = generate_signature(api_params, self.secret)

      #If in a batch, stash the params in the queue and bail
      if pending_batch
        batch_queue << api_params.map { |k,v| "#{k}=#{v}" }.join('&')
        return
      end

      # Call Facebook with POST request
      response = Net::HTTP.post_form( URI.parse(FB_URL), api_params )

      # Handle response
      self.last_response = response.body
      data = Yajl::Parser.parse(response.body)

      if data.is_a?(Hash) && data['error_msg']
        raise FacebookError.new(data['error_code'], data['error_msg'])
      end

      return data
    end

    def call_upload(method, filename, params={})
      content = File.open(filename, 'rb') { |f| f.read }
      api_params = params.dup

      # Prepare standard arguments for call
      api_params['method']      ||= method
      api_params['api_key']     ||= self.api_key
      api_params['format']      ||= self.format
      api_params['session_key'] ||= self.params['session_key']
      api_params['call_id']     ||= Time.now.to_f.to_s
      api_params['v']           ||= FB_API_VERSION

      convert_outgoing_params(api_params)
      api_params['sig'] = generate_signature(api_params, self.secret)
      boundary = Digest::MD5.hexdigest(content)

      header = {'Content-type' => "multipart/form-data, boundary=#{boundary}"}
      # Build query
      query = ''
      api_params.each { |a, v|
        query <<
          "--#{boundary}\r\n" <<
          "Content-Disposition: form-data; name=\"#{a}\"\r\n\r\n" <<
          "#{v}\r\n"
      }
      query <<
        "--#{boundary}\r\n" <<
        "Content-Disposition: form-data; filename=\"#{File.basename(filename)}\"\r\n" <<
        "Content-Transfer-Encoding: binary\r\n" <<
        "Content-Type: image/jpeg\r\n\r\n" <<
        content <<
        "\r\n" <<
        "--#{boundary}--"

      # Call Facebook with POST multipart/form-data request
      uri = method == 'video.upload' ? URI.parse(FB_VIDEO_URL) : URI.parse(FB_URL)
      response = Net::HTTP.start(uri.host) {|http| http.post uri.path, query, header}

      # Handle response
      self.last_response = response.body
      data = Yajl::Parser.parse(response.body)

      if data.is_a?(Hash) && data['error_msg']
        raise FacebookError.new(data['error_code'], data['error_msg'])
      end

      return data
    end

    #
    # Performs a batch API operation (batch.run)
    #
    # Example:
    #   results = fb.batch do 
    #     fb.application.getPublicInfo(...)
    #     fb.users.getInfo(...)
    #   end
    #
    # Options:
    #   * :raise_errors (default true) - since a batch returns results for
    #     multiple calls, some may return errors while others do not, by default
    #     an exception will be raised if any errors are found.  Set to 
    #     false to disable this and handle errors yourself
    def batch(options = {})
      return unless block_given?
      raise FacebookError.new(951, 'Batch already started') if pending_batch 

      self.batch_queue = []
      self.pending_batch = true
      options[:raise_errors] = true if options[:raise_errors].nil?

      yield self

      self.pending_batch = false
      results = call('batch.run', 
                     :method_feed => self.batch_queue, 
                     :serial_only => true)
      self.batch_queue = nil

      #Batch results are an array of JSON strings, parse each
      results.map! { |json| Yajl::Parser.parse(json) }

      results.each do |data|
        if data.is_a?(Hash) && data['error_msg']
          raise FacebookError.new(data['error_code'], data['error_msg'])
        end
      end if options[:raise_errors]

      results
    end

    def add_special_params(method, params)
      #call_as_apikey for Permissions API
      #ss Session secret
      #use_ssl_resources
    end

    #
    # Extracts and validates any Facebook parameters from the request, and
    # stores them in the client.
    # We look for parameters from POST, GET, then cookies, in that order. 
    # POST and GET are always more up-to-date than cookies, so we prefer 
    # those if they are available.
    #
    # Parameters:
    #   env   the Rack environment, or a Rack request
    #
    def extract_params(env)
      #Accept a Request object or the env
      if env.is_a?(Rack::Request)
        request = env
      else
        request = Rack::Request.new(env)
      end

      #Fetch from POST
      fb_params = get_params_from(request.POST, 'fb_sig')

      #Fetch from GET
      unless fb_params
        # note that with preload FQL, it's possible to receive POST params in
        # addition to GET, and a different prefix is used for each
        fb_get_params = get_params_from(request.GET, 'fb_sig') || {}
        fb_post_params = get_params_from(request.POST, 'fb_post_sig') || {}
        fb_get_params.merge!(fb_post_params) 
        fb_params = fb_get_params unless fb_get_params.empty?
      end

      #Fetch from cookies
      unless fb_params
        fb_params = get_params_from(request.cookies, self.api_key)
      end
      
      @params = convert_incoming_params(fb_params)
    end

    #
    # Converts some parameter values into more useful forms: 
    #   * 0 or 1 into true/false
    #   * Time values into Time objects
    #   * Comma separated lists into arrays
    #
    def convert_incoming_params(params)
      return nil unless params

      params.each do |key, value|
        case key
        when 'friends', 'linked_account_ids'
          params[key] = value.split(',')
        when /(time|expires)$/
          if value == '0'
            params[key] = nil
          else
            params[key] = Time.at(value.to_f)
          end
        when /^(logged_out|position_|in_|is_)/, /added$/
          params[key] = (value == '1')
        else
          params[key] = value
        end
      end

      params
    end

    #
    # Converts parameters being sent to Facebook from ruby objects to the
    # appropriate text representation
    #
    def convert_outgoing_params(params)
      json_encoder = Yajl::Encoder.new
      params.each do |key, value|
        params.delete(key) if value.nil?

        case value
        when Array, Hash
          params[key] = json_encoder.encode(value)
        when Time
          params[key] = value.to_i.to_s
        when TrueClass
          params[key] = '1'
        when FalseClass
          params[key] = '0'
        end
      end

      params
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
    # Parameters:
    #   params     A hash of parameters, i.e., from a HTTP request, or cookies
    #   namespace  prefix string for the set of parameters we want to verify. 
    #              i.e., fb_sig or fb_post_sig
    # Returns:
    #   the subset of parameters containing the given prefix, and also matching
    #   the signature associated with them, or nil if the params do not validate
    #
    def get_params_from(params,  namespace='fb_sig')
      prefix = "#{namespace}_"
      fb_params = Hash.new
      params.each do |key, value|
        if key =~ /^#{prefix}(.*)$/
          fb_params[$1] = value
        end
      end
      
      param_sig = params[namespace]
      gen_sig = generate_signature(fb_params, self.secret)
      return fb_params if param_sig == gen_sig
      nil
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
      str = fb_params.map { |k,v| "#{k}=#{v}" }.sort.join 
      Digest::MD5.hexdigest("#{str}#{secret}")
    end

    #
    # Allows making calls like `client.users.getInfo`
    #
    class APIProxy
      TYPES = %w[ admin application auth comments connect data events
        fbml feed fql friends groups links liveMessage notes notifications
        pages photos profile sms status stream users video ]

      alias :__class__ :class
      alias :__inspect__ :inspect
      instance_methods.each { |m| undef_method m unless m =~ /^(__|object_id)/ }
      alias :inspect :__inspect__

      def initialize name, obj
        @name, @obj = name, obj
      end

      def method_missing method, opts = {}
        @obj.call "#{@name}.#{method}", opts
      end
    end

    APIProxy::TYPES.each do |n|
      class_eval %[
        def #{n}
          (@proxies||={})[:#{n}] ||= APIProxy.new(:#{n}, self)
        end
      ]
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
      fb = Client.new(@options)
      fb.extract_params(env)

      env['facebook.client'] = fb

      #env["facebook.original_method"] = env["REQUEST_METHOD"]
      #env["REQUEST_METHOD"] = fb_params['request_method']

      return @app.call(env)
    end
  end
end
