require "httpclient"
require "json"
require "pp"
require "optparse"
require 'simple_uuid'
require 'time'

#
# An implementation of Ubiregi API client, which wraps sending HTTP requests and conversion of requests from/to JSON.
# The class is developed as an example of the API, it is not recommended to use this in production.
#
class UbiregiClient
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
    {
      "User-Agent" => "SampleAPI Client; en",
      "X-Ubiregi-Auth-Token" => @token,
      "X-Ubiregi-App-Secret" => @secret,
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
  
  private

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

if __FILE__ == $0

  $ENDPOINT = 'https://ubiregi.com/api/3/'

  OptionParser.new do |opt|
    opt.on("--secret SECRET") {|secret| $SECRET = secret }
    opt.on("--token TOKEN") {|token| $TOKEN = token }
    opt.on("--endpoint ENDPOINT") {|endpoint| $ENDPOINT = endpoint }
    
    opt.banner = "Usage: #{$0} [options] command\n" + "   available commands =>  account, menu, all-menu, post-checkout, checkouts"
    
    opt.parse!(ARGV)
  end
  
  client = UbiregiClient.new($SECRET, $TOKEN, $ENDPOINT)
  
  # Download account information
  account = client.account
  # Download menu items information
  menu_items = client.menu_items(account["menus"].first)
  # Download menu categories information
  categories = client.menu_categories(account["menus"].first)

  case ARGV.shift
  when "account"
    # Just print account
    pp account
    
  when "menu"
    # Print valid menus
    categories.select {|category|
      # Visible categories have non-null position
      category['position'] 
    }.sort {|x,y|
      # Sort by their position
      x["position"] <=> y["position"]
    }.each do |category|
      # Print the category name
      puts "#{category['name']}"
      
      menu_items.select {|item|
        # Filter menu items for the category
        item["category_id"] == category["id"]
      }.sort {|x,y|
        # Sort by their position
        x["position"] <=> y["position"]
      }.each do |item|
        # Print the |id|, |name|, |price|, |vat| percentage, and |price_type|
        puts "  #{item['id']} | #{item['name']} #{item['price']} (#{item['vat']}%, #{item['price_type']})"
      end
    end
    
  when "all-menu"
    # Print all menus
    pp categories
    pp menu_items
    
  when "checkouts"
    # Print all checkouts
    checkouts = client.checkouts
    pp checkouts
    
  when 'post-checkout'
    # Post a checkout
    
    payment_types = account["payment_types"]
    
    # Select only visible and intax menu items, and create checkout items for the menu items.
    checkout_items = menu_items.select {|item| item['category_id'] }.select {|item| item['price_type'] == 'intax' }.map do |item|
      {
        "menu_item_id" => item['id'],
        "sales" => (item['price'].to_f * 100 / (100 + item['vat'])).to_i,
        "tax" => (item['price'].to_f * item['vat'] / (100 + item['vat'])).to_i,
        'discount_sales' => 0,
        'discount_tax' => 0,
        'count' => 1,
      }
    end
    
    # Calculate the total amount of this bill.
    amount = checkout_items.inject(0) {|acc, item| acc + item['sales'] + item['tax'] }
    
    # Setup how the bill is payed.
    payments = [{
                  'payment_type_id' => payment_types.first['id'],
                  'amount' => amount
                }]
    
    # The complete checkout hash
    checkout = {
      'items_attributes' => checkout_items,
      'change' => 0,
      'guid' => SimpleUUID::UUID.new.to_guid,
      'paid_at' => Time.now.utc.iso8601,
      'payments_attributes' => payments,
      'customers_count' => 1,
      'customer_taggings_attributes' => [],
    }
    
    pp client.post_checkouts([checkout])
    
  end

end
