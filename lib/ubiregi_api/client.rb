#
# An implementation of Ubiregi API client, which wraps sending HTTP requests and conversion of requests from/to JSON.
# The class is developed as an example of the API, it is not recommended to use this in production.
#
class UbiregiAPI::Client
  # 
  # [secret]
  #  The secret to identify which the client app is accessing. The secret is generated in ubiregi.com.
  # [token]
  #  The token to identify which account is accessing. The token is generated for each installation of the app in ubiregi.com.
  # [endpoint]
  #  The API endpoint. This is almost only for development of this class.
  # 
  def initialize(secret, token, endpoint = "https://ubiregi.com/api/3/")
    @secret = secret
    @token = token
    @endpoint = endpoint
    
    @client = HTTPClient.new
  end
  
  #
  # Default HTTP request headers.
  # The headers defined are X-Ubiregi-Auth-Token and X-Ubiregi-App-Secret.
  # X-Ubiregi-Auth-Token is installation specific secret, shared with the ubiregi.com server, the user, and the client.
  # X-Ubiregi-App-Secret is app specific secret, shared with only the ubiregi.com server and the client.
  #
  def default_headers
    salt = Time.now.strftime("%Y%m%d%H%M%S")
    digest = Digest::SHA1.hexdigest(salt + @secret)
    app_secret = salt + ":" + digest

    {
      "User-Agent" => "SampleAPI Client; en",
      "X-Ubiregi-Auth-Token" => @token,
      "X-Ubiregi-App-Secret" => app_secret,
    }
  end
  
  # 
  # Download the information of the account.
  # The result contains only hash for 'account' key of the response.
  # 
  # [&block]
  #  If given, the block will be yielded with raw response converted to hash.
  # 
  def account(&block)
    response = _get("accounts/current")
    yield(response) if block_given?
    response["account"]
  end

  #
  # Download whole menu items of a menu.
  # One call to the method may generate more than one http GET requests to download all menu items.
  #
  # [menu_id]
  #  The id of menu to download items.
  #
  # [&block]
  #  If given, the block will be yielded with each raw response converted to hash.
  # 
  def menu_items(menu_id, &block)
    _index("menus/#{menu_id}/items", "items", &block)
  end
  
  #
  # Download whole menu categories of a menu.
  # One call to this method may generate more than one http GET requests.
  #
  # [menu_id]
  #  The id of menu to download categories.
  # 
  # [&block]
  #  If given, the block will be yielded with each raw response converted to hash.
  #
  def menu_categories(menu_id, &block)
    _index("menus/#{menu_id}/categories", "categories", &block)
  end

  #
  # Download whole checkouts of the account.
  # If you have a lot of checkouts already registered in ubiregi.com, please do not call this.
  # (It will take very long time, and should be meaningless.)
  #
  # [&block]
  #  If given, the block will be yielded with each raw response converted to hash.
  #
  def checkouts(&block)
    _index("checkouts", "checkouts")
  end
  
  #
  # Send a post request to register checkouts in the server.
  # 
  # [checkouts]
  #  Array of hash which represents one checkout.
  #
  def post_checkouts(checkouts)
    _post("checkouts", "checkouts" => checkouts)
  end
  
  def _index(url, collection, acc = [], &block)
    response = _get(url)

    yield(response) if block
    
    if next_url = response["next-url"]
      _index(next_url, collection, acc + response[collection])
    else
      acc + response[collection]
    end
  end
  
  def _get(url_or_path, query = {}, ext_headers = {})
    if url_or_path !~ /^http/
      url_or_path = @endpoint + url_or_path
    end
    STDERR.print "Sending GET request to #{url_or_path} ..."
    result = JSON.parse(@client.get(url_or_path, query, self.default_headers.merge(ext_headers)).body)
    STDERR.puts " done"
    result
  end

  def _post(url_or_path, content, query = {}, ext_headers = {})
    if url_or_path !~ /^http/
      url_or_path = @endpoint + url_or_path
    end

    STDERR.print "Sending POST request to #{url_or_path} ..."
    result = JSON.parse(@client.post(url_or_path, 
                                     content.to_json,
                                     self.default_headers.merge("Content-Type" => "application/json").merge(ext_headers)).body)
    STDERR.puts " done"
    result
  end
end

