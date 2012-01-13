require "rack-idempotent/version"

module Rack
  class Idempotent
    RETRY_LIMIT = 5

    class RetryLimitExceeded < Exception; end
    class HTTPException < Exception
      attr_reader :status
      def initialize(status)
        @status = status
      end
    end

    def initialize(app)
      @app= app
    end

    def call(env)
      env['client.retries'] = 0
      status, headers, body = nil
      begin
        dup_env = env.dup
        status, headers, body = @app.call(dup_env)
        raise HTTPException.new(status) if status == 502
        env.merge!(dup_env)
        [status, headers, body]
      rescue Errno::ETIMEDOUT, HTTPException
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
