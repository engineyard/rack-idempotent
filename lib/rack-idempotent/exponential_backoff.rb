class Rack::Idempotent::ExponentialBackoff
  attr_reader :max_retries, :max_retry_interval, :min_retry_interval

  def initialize(options={})
    @max_retries = options[:max_retries] || Rack::Idempotent::DEFAULT_RETRY_LIMIT
    @min_retry_interval = options[:min_retry_interval] || 0.5
    @max_retry_interval = options[:max_retry_interval] || 1800
  end

  def call(request, response, exception)
    request.env["idempotent.requests.count"] ||= 0
    request.env["idempotent.requests.count"] += 1
    request.env["idempotent.requests.sleep"] ||= (@min_retry_interval / 2)
    request.env["idempotent.requests.sleep"] *= 2

    if request.env["idempotent.requests.sleep"] > @max_retry_interval
      request.env["idempotent.requests.sleep"] = @max_retry_interval
    end
    if request.env["idempotent.requests.count"] >= @max_retries
      raise Rack::Idempotent::RetryLimitExceeded.new(
        request.env["idempotent.requests.exceptions"]
      )
    end
    delay(request.env["idempotent.requests.sleep"])
  end

  def delay(secs)
    sleep(secs)
  end
end
