require File.expand_path('../../spec_helper', __FILE__)

describe Rack::Idempotent do
  class SleepMonitor
    class << self
      attr_accessor :sleeps
    end
    def self.delay(secs)
      self.sleeps << secs
    end
    def self.reset
      self.sleeps = []
    end
  end

  before(:each) do
    TestCall.errors = []
    RecordRequests.reset
    SleepMonitor.reset
  end
  let(:client) do
    Rack::Client.new do
      use Rack::Lint
      use Rack::Idempotent, {:retry => Rack::Idempotent::ExponentialBackoff.new}
      use Rack::Lint
      use RecordRequests
      run TestCall
    end
  end

  class Rack::Idempotent::ExponentialBackoff
    def delay(secs)
      SleepMonitor.delay(secs)
    end
  end

  describe "using Rack::Idempotent::ExponentialBackoff" do
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

    it "should raise RetryLimitExceeded when the request fails too many times" do
      retry_limit = Rack::Idempotent::ExponentialBackoff.new.max_retries
      TestCall.errors = (retry_limit + 1).times.map {|i| 503}
      lambda {
        client.get("http://example.org/")
      }.should raise_exception Rack::Idempotent::RetryLimitExceeded
      RecordRequests.requests.count.should == retry_limit
      RecordRequests.responses.count.should == retry_limit
    end

    it 'should sleep between retries' do
      TestCall.errors = [503]
      client.get("http://example.org/")
      SleepMonitor.sleeps.count.should == 1
    end

    it 'should sleep for increasingly longer times' do
      retry_limit = Rack::Idempotent::ExponentialBackoff.new.max_retries
      TestCall.errors = (retry_limit + 1).times.map {|i| 503}
      begin
        client.get("http://example.org/")
      rescue Rack::Idempotent::RetryLimitExceeded
        # Ignore, this should be thrown
      ensure
        SleepMonitor.sleeps.count.should == retry_limit - 1
        SleepMonitor.sleeps.each_index do |i|
          SleepMonitor.sleeps[i].should > (i == 0 ? 0 : SleepMonitor.sleeps[i - 1])
        end
      end
    end
  end
end
