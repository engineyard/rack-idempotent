require 'spec_helper'

describe "Rack::Idempotent" do
  describe "with defaults" do
    it "should not retry if succesful response" do
      client = Rack::Client.new do
        use Rack::Lint
        use Rack::Idempotent
        run lambda{|env| [200, {"Content-Type" => "text/plain"}, []]}
      end
      client.get("http://example.org/")
    end
  end
end
