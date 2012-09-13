class Rack::Idempotent::HTTPException < StandardError
  attr_reader :status, :headers, :body, :request
  def initialize(status, headers, body, request)
    @status, @headers, @body, @request = status, headers, body, request
  end

  def to_s
    @status.to_s
  end
end
