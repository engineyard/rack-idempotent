class Rack::Idempotent::RetryLimitExceeded < StandardError
  attr_reader :idempotent_exceptions

  def initialize(idempotent_exceptions)
    @idempotent_exceptions = idempotent_exceptions
  end
end
