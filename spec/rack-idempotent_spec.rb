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
    def self.call(env); self.errors.shift.tap{|e| raise(e) if e}; [200, {}, []]; end
  end
  before(:each){ CaptureEnv.env = nil }
  it "should retry Errno::ETIMEDOUT" do
    RaiseUp.errors = [Errno::ETIMEDOUT, Errno::ETIMEDOUT]
    client = Rack::Client.new do
      use CaptureEnv
      use Rack::Idempotent
      run RaiseUp
    end

    client.get("/doesntmatter")

    env = CaptureEnv.env
    env['client.retries'].should == 2
  end
  it "should raise Rack::Idempotent::RetryLimitExceeded when retry limit is reached" do
    RaiseUp.errors = (Rack::Idempotent::RETRY_LIMIT + 1).times.map{|i| Errno::ETIMEDOUT}
    client = Rack::Client.new do
      use CaptureEnv
      use Rack::Idempotent
      run RaiseUp
    end

    lambda { client.get("/doesntmatter") }.should raise_exception(Rack::Idempotent::RetryLimitExceeded)

    env = CaptureEnv.env
    env['client.retries'].should == Rack::Idempotent::RETRY_LIMIT
  end
end
