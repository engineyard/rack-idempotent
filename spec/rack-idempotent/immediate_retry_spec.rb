require File.expand_path('../../spec_helper', __FILE__)

describe Rack::Idempotent do
  before(:each) do
    TestCall.errors = []
    RecordRequests.reset
  end

  configurations = {
    "defaults" => {},
    "custom max_retries" => {:max_retries => 50},
  }

  configurations.each_pair do |name,opts|
    describe "using Rack::Idempotent::ImmediateRetry with #{name}" do
      let(:client) do
        Rack::Client.new do
          use Rack::Idempotent, {
            :retry => Rack::Idempotent::ImmediateRetry.new(opts)
          }
          use Rack::Lint
          use RecordRequests
          run TestCall
        end
      end

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
        retry_limit = rack_idempotent(client).retry_policy.max_retries
        TestCall.errors = (retry_limit + 1).times.map {|i| 503}
        lambda {
          client.get("http://example.org/")
        }.should raise_exception Rack::Idempotent::RetryLimitExceeded
        RecordRequests.requests.count.should == retry_limit
        RecordRequests.responses.count.should == retry_limit
      end
    end
  end
end
