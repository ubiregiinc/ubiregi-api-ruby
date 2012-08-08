# 1. Load UbiregiAPI library

    require "ubiregi_api"

Make sure library search path is configured properly.

# 2. Instantiate Client

    client = UbiregiAPI::Client.new(secret, auth_token)

`secret` and `auth_token` can be found your developer page (https://ubiregi.com/developer).

# 3. Send GET request

    client._get('customers')

# 4. Send POST request

    client._post('customers', post_data)

`post_data` must be a JSON transformable value (`Hash` or `Array`).

# 5. Retrieve Whole Collection

    client._index('customers', 'customers')

`_index` method can be used to retrieve all data included in a collection.
It understands `next-url` field included in the response, and send GET request again.

