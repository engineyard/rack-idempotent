require 'spec_helper'

describe Rack::Idempotent do
  class CaptureEnv
    class << self; attr_accessor :env; end
    def initialize(app); @app=app; end
    def call(env)
      tuple = @app.call(env)
      self.class.env = env
      tuple
    end
  end
  it "should retry Errno::ETIMEDOUT" do
    $to_raise = [Errno::ETIMEDOUT, Errno::ETIMEDOUT]

    client = Rack::Client.new do
      use CaptureEnv
      use Rack::Idempotent
      run lambda{|env| $to_raise.shift.tap{|e| raise(e) if e}; [200, {}, []]}
    end
    response = client.get("/doesntmatter")
    env = CaptureEnv.env
    env['client.retries'].should == 2
  end
end
