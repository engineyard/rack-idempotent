class Rack::Idempotent::ImmediateRetry

  def initialize(options={})
    @limit = options[:limit] || 5
  end

  def call(request, response, exception)
    request.env["idempotent.requests.count"] ||= 0
    request.env["idempotent.requests.count"] += 1

    raise RetryLimitExceeded.new(request.env["idempotent.requests.exceptions"])
  end
end
