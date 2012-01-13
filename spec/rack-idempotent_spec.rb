require 'spec_helper'

describe Rack::Idempotent do
  class CaptureEnv
    class << self; attr_accessor :env; end
    def initialize(app); @app=app; end
    def call(env)
      @app.call(env)
    ensure
      self.class.env = env
    end
  end
  class RaiseUp
    class << self; attr_accessor :errors; end
    def self.call(env)
      error = self.errors.shift
      raise error if error.is_a?(Class)
      status_code = error || 200
      [status_code, {}, []]
    end
  end

  before(:each){ CaptureEnv.env = nil }
  let(:client) do
    Rack::Client.new do
      use CaptureEnv
      use Rack::Idempotent
      run RaiseUp
    end
  end

  it "should retry Errno::ETIMEDOUT" do
    RaiseUp.errors = [Errno::ETIMEDOUT, Errno::ETIMEDOUT]
    client.get("/doesntmatter")

    env = CaptureEnv.env
    env['client.retries'].should == 2
  end

  it "should raise Rack::Idempotent::RetryLimitExceeded when retry limit is reached" do
    RaiseUp.errors = (Rack::Idempotent::RETRY_LIMIT + 1).times.map{|i| Errno::ETIMEDOUT}

    lambda { client.get("/doesntmatter") }.should raise_exception(Rack::Idempotent::RetryLimitExceeded)

    env = CaptureEnv.env
    env['client.retries'].should == Rack::Idempotent::RETRY_LIMIT
  end

  it "retries 502" do
    RaiseUp.errors = [502]
    client.get("/something")
    env = CaptureEnv.env
    env['client.retries'].should == 1
  end
end
