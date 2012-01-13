require "rack-idempotent/version"

module Rack
  class Idempotent
    RETRY_LIMIT = 5

    class RetryLimitExceeded < Exception; end

    def initialize(app)
      @app= app
    end

    def call(env)
      env['client.retries'] = 0
      begin
        @app.call(env)
      rescue Errno::ETIMEDOUT
        if env['client.retries'] > RETRY_LIMIT - 1
          raise(RetryLimitExceeded)
        else
          env['client.retries'] += 1
          retry
        end
      end
    end
  end
end
