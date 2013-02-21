# Rack::Idempotent

This rack middleware intends to handle retry logic for rack-client.

Rack::Idempotent rescues and retries low-level errors and 'safe to retry' http response codes.

Default retry limit is currently set to 5.

Handled low-level Net::HTTP exceptions include:

* `Errno::ETIMEDOUT`
* `Errno::ECONNREFUSED`
* `Errno::EHOSTUNREACH`

Response status codes that are retried:

* 408: Request Timeout
* 502: Bad Gateway
* 503: Service Unavailable
* 504: Gateway Timeout

If the retry limit is exceeded, Rack::Idemptotent will raise `Rack::Idempotent::RetryLimitExceeded`.

The exceptions raised are stored as an array available via `Rack::Idempotent::RetryLimitExceeded#idempotent_exceptions`

## Installation

Add this line to your application's Gemfile:

    gem 'rack-idempotent'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-idempotent

## Usage

Add Rack::Idempotent as a Rack::Client middleware as close to the handler as possible:

```ruby
client = Rack::Client.new do
  use EY::ApiHMAC::ApiAuth::Client, *ServiceClient.hmac_keys
  use Rack::Idempotent
  run Rack::Client::Handler::NetHTTP
end
```

### Configuration

### Exponential Backoff

* Defaults
  * ```max_retries``` = 5
  * ```min_retry_interval``` = 0.5 (seconds)
  * ```max_retry_interval``` = 1800 (seconds)

```ruby
Rack::Client.new do
  use Rack::Idempotent, {
    :retry => Rack::Idempotent::ExponentialBackoff.new(
      :max_retries        => 50,
      :min_retry_interval => 1.0,
      :max_retry_interval => 30,
    ),
  }
  use Rack::Lint
  run App
end
```

### Immediate Retry

```ruby
Rack::Client.new do
  use Rack::Idempotent, {
    :retry => Rack::Idempotent::ImmediateRetry.new(max_retries: 50),
  }
  use Rack::Lint
  run App
end
```


## Running Tests

    $ bundle exec rake

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
