class Rack::Idempotent::ImmediateRetry
  def self.limit
    return Rack::Idempotent::DEFAULT_RETRY_LIMIT
  end

  def self.call(request, response, exception)
    request.env["idempotent.requests.count"] ||= 0
    request.env["idempotent.requests.count"] += 1

    if request.env["idempotent.requests.count"] >= self.limit
      raise Rack::Idempotent::RetryLimitExceeded.new(
        request.env["idempotent.requests.exceptions"]
      )
    end
  end
end
