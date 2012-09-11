class Rack::Idempotent::ImmediateRetry
  def self.call(request, response, exception)
    limit = Rack::Idempotent::DEFAULT_RETRY_LIMIT
    request.env["idempotent.requests.count"] ||= 0
    request.env["idempotent.requests.count"] += 1

    if request.env["idempotent.requests.count"] >= limit
      raise Rack::Idempotent::RetryLimitExceeded.new(
        request.env["idempotent.requests.exceptions"]
      )
    end
  end
end
