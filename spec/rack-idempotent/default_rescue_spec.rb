require File.expand_path('../../spec_helper', __FILE__)

describe Rack::Idempotent do
  before(:each) do
    TestCall.errors = []
    RecordRequests.reset
  end
  let(:client) do
    Rack::Client.new do
      use Rack::Lint
      use Rack::Idempotent, {:rescue => Rack::Idempotent::DefaultRescue.new}
      use Rack::Lint
      use RecordRequests
      run TestCall
    end
  end

  describe "using Rack::Idempotent::DefaultRescue" do
    [408, 502, 503, 504].each do |status|
      it "should retry GET requests that result in #{status}" do
        TestCall.errors = [status]
        client.get("http://example.org/")

        RecordRequests.requests.count.should == 2

        RecordRequests.responses.count.should == 2
        RecordRequests.responses[0][0].should == status
        RecordRequests.responses[1][0].should == 200
      end
    end

    [200, 201, 301, 302, 400, 401, 403, 404, 500].each do |status|
      it "should not retry GET requests that result in #{status}" do
        TestCall.errors = [status]
        begin
          client.get("http://example.org/")
          status.should < 400
        rescue Rack::Idempotent::HTTPException => e
          e.status.should == status
          e.status.should >= 400
        end
        RecordRequests.requests.count.should == 1
      end
    end

    [502, 503, 504].each do |status|
      it "should retry POST requests that result in #{status}" do
        TestCall.errors = [status]
        client.post("http://example.org/")

        RecordRequests.requests.count.should == 2

        RecordRequests.responses.count.should == 2
        RecordRequests.responses[0][0].should == status
        RecordRequests.responses[1][0].should == 200
      end
    end

    [200, 201, 301, 302, 400, 401, 403, 404, 408, 500].each do |status|
      it "should not retry POST requests that result in #{status}" do
        TestCall.errors = [status]
        begin
          client.post("http://example.org/")
          status.should < 400
        rescue Rack::Idempotent::HTTPException => e
          e.status.should == status
          e.status.should >= 400
        end
        RecordRequests.requests.count.should == 1
      end
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
      retry_limit = Rack::Idempotent::DEFAULT_RETRY_LIMIT
      TestCall.errors = (retry_limit + 1).times.map {|i| 503}
      lambda {
        client.get("http://example.org/")
      }.should raise_exception Rack::Idempotent::RetryLimitExceeded
      RecordRequests.requests.count.should == retry_limit
      RecordRequests.responses.count.should == retry_limit
    end
    
    [Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH].each do |ex|
      it "should retry requests that result in #{ex}" do
        TestCall.errors = [ex]
        client.get("http://example.org/")

        RecordRequests.requests.count.should == 2
        exceptions = RecordRequests.requests.last["idempotent.requests.exceptions"]
        exceptions.count.should == 1
        exceptions.first.class.should == ex
      end
    end
    
    [Errno::EHOSTDOWN, Errno::ECONNRESET, Errno::ENETRESET].each do |ex|
      it "should not retry requests that result in #{ex}" do
        TestCall.errors = [ex]
        lambda {
          client.get("http://example.org/")
        }.should raise_exception ex
        RecordRequests.requests.count.should == 1
      end
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
