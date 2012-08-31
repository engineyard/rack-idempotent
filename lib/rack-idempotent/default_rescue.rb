class Rack::Idempotent::DefaultRescue
  RETRY_HTTP_CODES = [502, 503, 504]
  IDEMPOTENT_ERROR_CLASSES = [Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH]

  def self.call(options={})
    if response = options[:response]
    elsif exception = options[:exception]
    else raise "wtf"
    end

  end
end
