require File.expand_path("../../lib/rack-idempotent", __FILE__)

Bundler.require(:test)

class RecordRequests
  class << self
    attr_accessor :requests
    attr_accessor :responses

    def reset
      self.requests = []
      self.responses = []
    end
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    response = @app.call(env)
  ensure
    self.class.requests << env
    self.class.responses << response
  end
end

class TestCall
  class << self
    attr_accessor :errors
  end

  def self.call(env)
    error = nil
    if self.errors
      error = self.errors.shift
      raise error if error.is_a?(Class)
    end
    status_code = error || 200
    [status_code, {"Content-Type" => "text/plain"}, []]
  end
end
