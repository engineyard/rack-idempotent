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

  [502, 503, 504, 408].each do |code|
    it "retries #{code}" do
      RaiseUp.errors = [code]
      client.get("/something")
      env = CaptureEnv.env
      env['client.retries'].should == 1
    end
  end

  it "should store exceptions raised" do
    RaiseUp.errors = [502, Errno::ECONNREFUSED, 408, 504, Errno::EHOSTUNREACH, Errno::ETIMEDOUT]
    errors = RaiseUp.errors.dup
    exception = nil

    begin
      client.get("/doesntmatter")
    rescue Rack::Idempotent::RetryLimitExceeded => e
      exception = e
    end

    exception.should_not be_nil
    exception.idempotent_exceptions.size.should == 6
    exception.idempotent_exceptions.map{|ie| ie.is_a?(Rack::Idempotent::HTTPException) ? ie.status : ie.class}.should == errors
  end

end
