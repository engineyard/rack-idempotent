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

  it "should retry Rack::Idempotent::Retryable" do
    RaiseUp.errors = [Rack::Idempotent::Retryable, Rack::Idempotent::Retryable]
    client.get("/alsodoesntmatter")

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
    it "retries GET #{code}" do
      RaiseUp.errors = [code]
      client.get("/something")
      env = CaptureEnv.env
      env['client.retries'].should == 1
    end
  end

  [502, 503, 504].each do |code|
    it "retries POST #{code}" do
      RaiseUp.errors = [code]
      client.post("/something")
      env = CaptureEnv.env
      env['client.retries'].should == 1
    end
  end

  it "doesn't retry POST when return code is 408" do
    RaiseUp.errors = [408]
    lambda do
      client.post("/something")
    end.should raise_error(Rack::Idempotent::HTTPException)
    env = CaptureEnv.env
    env['client.retries'].should == 0
  end

  it "should be able to rescue http exception via standard error" do
    RaiseUp.errors = [408]

    begin
      client.post("/something")
    rescue => e
      # works
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

  it "should be able to rescue retry limit exceeded via standard error" do
    RaiseUp.errors = (0...Rack::Idempotent::RETRY_LIMIT.succ).map{|_| 503 }

    begin
      res = client.get("/doesntmatter")
    rescue => e
      # works
    end
  end

end
