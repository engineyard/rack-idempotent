require 'spec_helper'

describe Rack::Idempotent do
  before(:each) do
    TestCall.errors = []
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

    it "should raise RetryLimitExceeded when the request fails too many times" do
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

    describe "does what the README says it does and" do
      it 'has a retry limit of 5' do
        Rack::Idempotent::DEFAULT_RETRY_LIMIT.should == 5
      end

      [Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH].each do |e|
        it "retries on #{e}" do
          TestCall.errors = [e]
          client.get("http://example.org/")

          RecordRequests.requests.count.should == 2
          exceptions = RecordRequests.requests.last["idempotent.requests.exceptions"]
          exceptions.count.should == 1
          exceptions.first.class.should == e

          RecordRequests.responses.count.should == 2
          RecordRequests.responses.last[0].should == 200
        end
      end

      [408, 502, 503, 504].each do |status|
        it "retries on #{status}" do
          TestCall.errors = [status]
          client.get("http://example.org/")

          RecordRequests.requests.count.should == 2

          RecordRequests.responses.count.should == 2
          RecordRequests.responses[0][0].should == status
          RecordRequests.responses[1][0].should == 200
        end
      end

      it 'raises RetryLimitExceeded if the retry limit is exceeded' do
        retry_limit = Rack::Idempotent::DEFAULT_RETRY_LIMIT
        TestCall.errors = (retry_limit + 1).times.map {|i| 408}
        lambda {
          client.get("http://example.org/")
        }.should raise_exception Rack::Idempotent::RetryLimitExceeded
        RecordRequests.requests.count.should == retry_limit
        RecordRequests.responses.count.should == retry_limit
      end

      it 'stores any exceptions raised in RetryLimitExceeded.idempotent_exceptions' do
        retry_limit = Rack::Idempotent::DEFAULT_RETRY_LIMIT
        TestCall.errors = (retry_limit + 1).times.map {|i| Errno::ETIMEDOUT}
        lambda {
          begin
            client.get("http://example.org/")
          rescue Rack::Idempotent::RetryLimitExceeded => e
            e.idempotent_exceptions.should_not be_nil
            exceptions = e.idempotent_exceptions
            exceptions.count.should == retry_limit
            exceptions.each do |ex|
              ex.class.should == Errno::ETIMEDOUT
            end
            raise
          end
        }.should raise_exception Rack::Idempotent::RetryLimitExceeded

        RecordRequests.requests.count.should == retry_limit
        RecordRequests.responses.count.should == retry_limit
      end
    end

    describe "does what v0.0.3 does and" do
      [502, 503, 504].each do |status|
        it "retries POST requests if the status is #{status}" do
          TestCall.errors = [status]
          client.post("http://example.org/")

          RecordRequests.requests.count.should == 2

          RecordRequests.responses.count.should == 2
          RecordRequests.responses[0][0].should == status
          RecordRequests.responses[1][0].should == 200
        end
      end

      it 'does not retry a POST if the status is 408' do
        TestCall.errors = [408]
        lambda {
          client.post("http://example.org/")
        }.should raise_exception Rack::Idempotent::HTTPException

        RecordRequests.requests.count.should == 1

        RecordRequests.responses.count.should == 1
        RecordRequests.responses[0][0].should == 408
      end

      it 'retries if a Rack::Idempotent::Retryable exception is thrown' do
        TestCall.errors = [Rack::Idempotent::Retryable]
        client.get("http://example.org/")

        RecordRequests.requests.count.should == 2
        exceptions = RecordRequests.requests.last["idempotent.requests.exceptions"]
        exceptions.count.should == 1
        exceptions.first.class.should == Rack::Idempotent::Retryable

        RecordRequests.responses.count.should == 2
        RecordRequests.responses.last[0].should == 200
      end

      it 'is able to rescue http exception via standard error' do
        TestCall.errors = [400]
        begin
          client.post("http://example.org/")
        rescue => e
          e.class.should == Rack::Idempotent::HTTPException
        end
      end

      it 'is able to rescue retry limit exceeded via standard error' do
        retry_limit = Rack::Idempotent::DEFAULT_RETRY_LIMIT
        TestCall.errors = (retry_limit + 1).times.map {|i| Errno::ETIMEDOUT}
        begin
          client.post("http://example.org/")
        rescue => e
          e.class.should == Rack::Idempotent::RetryLimitExceeded
        end
      end
    end
  end
end
