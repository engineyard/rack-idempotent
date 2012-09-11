class Rack::Idempotent::DefaultRescue
  GET_RETRY_HTTP_CODES = [408, 502, 503, 504]
  POST_RETRY_HTTP_CODES = [502, 503, 504]
  IDEMPOTENT_ERROR_CLASSES = [Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH]

  def self.call(options={})
    exception = options[:exception]
    status = nil
    method = nil

    if exception
      if IDEMPOTENT_ERROR_CLASSES.include?(exception.class)
        return true
      elsif exception.class == Rack::Idempotent::HTTPException
        status = exception.status
        method = exception.request.env["REQUEST_METHOD"]
      else
        return false
      end
    end

    unless status && method
      status = options[:response].status
      method = options[:request].env["REQUEST_METHOD"]
    end

    if method == "GET"
      GET_RETRY_HTTP_CODES.include?(status)
    elsif method == "POST"
      POST_RETRY_HTTP_CODES.include?(status)
    else
      false
    end
  end
end
