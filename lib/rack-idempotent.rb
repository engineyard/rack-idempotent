require "rack-idempotent/version"

class Rack::Idempotent
  DEFAULT_RETRY_LIMIT = 5

  autoload :ImmediateRetry, 'rack-idempotent/immediate_retry'
  autoload :ExponentialBackoff, 'rack-idempotent/exponential_backoff'
  autoload :DefaultRescue, 'rack-idempotent/default_rescue'
  autoload :RetryLimitExceeded, 'rack-idempotent/retry_limit_exceeded'

  attr_reader :retry_policy, :rescue_policy

  def initialize(app, options={})
    @app           = app
    @retry_policy  = options[:retry] || Rack::Idempotent::ImmediateRetry
    @rescue_policy = options[:rescue] || Rack::Idempotent::DefaultRescue
  end

  def call(env)
    request = Rack::Request.new(env)
    response = nil
    exception = nil
    while true
      retry_policy.call(request, response, exception) if response || exception
      response, exception = nil

      begin
        status, headers, body = @app.call(env.dup)
        response = Rack::Response.new(body, status, headers)
        next if rescue_policy.call(response: response, request: request)
        return [status, headers, body]
      rescue => exception
        if rescue_policy.call(exception: exception, request: request)
          request.env["idempotent.requests.exceptions"] ||= []
          request.env["idempotent.requests.exceptions"] << exception
          next
        end
        raise
      end
    end
  end
end
