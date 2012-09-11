require "rack-idempotent/version"

class Rack::Idempotent
  DEFAULT_RETRY_LIMIT = 5

  # Retry policies
  autoload :ImmediateRetry, 'rack-idempotent/immediate_retry'
  autoload :ExponentialBackoff, 'rack-idempotent/exponential_backoff'

  # Rescue policies
  autoload :DefaultRescue, 'rack-idempotent/default_rescue'

  # Exceptions
  autoload :HTTPException, 'rack-idempotent/http_exception'
  autoload :RetryLimitExceeded, 'rack-idempotent/retry_limit_exceeded'
  autoload :Retryable, 'rack-idempotent/retryable'

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
        raise HTTPException.new(status, headers, body, request) if status >= 400
        response = Rack::Response.new(body, status, headers)
        next if rescue_policy.call(response: response, request: request)
        return [status, headers, body]
      rescue Rack::Idempotent::Retryable => exception
        request.env["idempotent.requests.exceptions"] ||= []
        request.env["idempotent.requests.exceptions"] << exception
        next
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
