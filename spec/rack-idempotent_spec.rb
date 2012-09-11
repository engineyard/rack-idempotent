require 'spec_helper'

describe Rack::Idempotent do
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

  before(:each) do
    RecordRequests.reset
  end
  let(:client) do
    Rack::Client.new do
      use Rack::Lint
      use Rack::Idempotent
      use Rack::Lint
      use RecordRequests
      run TestCall
    end
  end

  describe "with defaults" do
    it "should not retry if succesful response" do
      client.get("http://example.org/")
      RecordRequests.requests.count.should == 1
    end

    it "should retry if it gets one unsuccesful response" do
      TestCall.errors = [503]
      client.get("http://example.org/")

      RecordRequests.requests.count.should == 2

      RecordRequests.responses.count.should == 2
      RecordRequests.responses[0][0].should == 503
      RecordRequests.responses[1][0].should == 200
    end

    it "should retry if it gets more than one unsuccesful response" do
      TestCall.errors = [503, 504]
      client.get("http://example.org/")

      RecordRequests.requests.count.should == 3

      RecordRequests.responses.count.should == 3
      RecordRequests.responses[0][0].should == 503
      RecordRequests.responses[1][0].should == 504
      RecordRequests.responses[2][0].should == 200
    end

    it "should raise RetryLimitExceeded when the connection fails too many times" do
      retry_limit = Rack::Idempotent::DEFAULT_RETRY_LIMIT
      TestCall.errors = (retry_limit + 1).times.map {|i| 503}
      lambda {
        client.get("http://example.org/")
      }.should raise_exception Rack::Idempotent::RetryLimitExceeded
      RecordRequests.requests.count.should == retry_limit
      RecordRequests.responses.count.should == retry_limit
    end

    it "should retry if the connection times out once" do
      TestCall.errors = [Errno::ETIMEDOUT]
      client.get("http://example.org/")

      RecordRequests.requests.count.should == 2
      exceptions = RecordRequests.requests.last["idempotent.requests.exceptions"]
      exceptions.count.should == 1
      exceptions.first.class.should == Errno::ETIMEDOUT

      RecordRequests.responses.count.should == 2
      RecordRequests.responses.last[0].should == 200
    end

    it "should retry if the connection times out more than once" do
      TestCall.errors = [Errno::ETIMEDOUT, Errno::ETIMEDOUT]
      client.get("http://example.org/")

      RecordRequests.requests.count.should == 3
      exceptions = RecordRequests.requests.last["idempotent.requests.exceptions"]
      exceptions.count.should == 2
      exceptions.first.class.should == Errno::ETIMEDOUT

      RecordRequests.responses.count.should == 3
      RecordRequests.responses.last[0].should == 200
    end

    it "should raise RetryLimitExceeded when the connection times out too many times" do
      retry_limit = Rack::Idempotent::DEFAULT_RETRY_LIMIT
      TestCall.errors = (retry_limit + 1).times.map {|i| Errno::ETIMEDOUT}
      lambda {
        client.get("http://example.org/")
      }.should raise_exception Rack::Idempotent::RetryLimitExceeded
      RecordRequests.requests.count.should == retry_limit
      RecordRequests.responses.count.should == retry_limit
    end
  end
end
