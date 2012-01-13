# Rack::Idempotent

This rack middleware intends to handle retry logic for rack-client.

Rack::Idempotent rescues and retries low-level errors and 'safe to retry' http response codes.

Default retry limit is currently set to 5.

Handled low-level Net::HTTP exceptions include:
* Errno::ETIMEDOUT
* Errno::ECONNREFUSED
* Errno::EHOSTUNREACH

Response status codes that are retried:
* 408: Request Timeout
* 502: Bad Gateway
* 503: Service Unavailable
* 504: Gateway Timeout

If the retry limit is exceeded, Rack::Idemptotent will raise Rack::Idempotent::RetryLimitExceeded.

The exceptions raised are stored as an array available via Rack::Idempotent::RetryLimitExceeded#idempotent\_exceptions

## Installation

Add this line to your application's Gemfile:

    gem 'rack-idempotent'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-idempotent

## Usage

Add Rack::Idempotent as a Rack::Client middleware as close to the handler as possible:

  client = Rack::Client.new do
    use EY::ApiHMAC::ApiAuth::Client, *ServiceClient.hmac_keys
    use Rack::Idempotent
    run Rack::Client::Handler::NetHTTP
  end

## Running Tests

  $ bundle exec rake

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
