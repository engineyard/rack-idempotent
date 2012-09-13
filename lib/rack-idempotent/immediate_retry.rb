class Rack::Idempotent::ImmediateRetry
  attr_reader :max_retries

  def initialize(options={})
    @max_retries = options[:max_retries] || Rack::Idempotent::DEFAULT_RETRY_LIMIT
  end

  def call(request, response, exception)
    request.env["idempotent.requests.count"] ||= 0
    request.env["idempotent.requests.count"] += 1

    if request.env["idempotent.requests.count"] >= max_retries
      raise Rack::Idempotent::RetryLimitExceeded.new(
        request.env["idempotent.requests.exceptions"]
      )
    end
  end
end
