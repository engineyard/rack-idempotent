require "rack-idempotent/version"

module Rack
  class Idempotent
    RETRY_LIMIT = 5
    RETRY_HTTP_CODES = [502, 503, 504]
    IDEMPOTENT_HTTP_CODES = RETRY_HTTP_CODES + [408]
    IDEMPOTENT_ERROR_CLASSES = [Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH]

    class RetryLimitExceeded < Exception
      attr_reader :idempotent_exceptions
      def initialize(idempotent_exceptions)
        @idempotent_exceptions = idempotent_exceptions
      end
    end

    class HTTPException < Exception
      attr_reader :status, :headers, :body
      def initialize(status, headers, body)
        @status, @headers, @body = status, headers, body
      end

      def to_s
        @status.to_s
      end
    end

    class Retryable < StandardError
    end

    def initialize(app)
      @app= app
    end

    def call(env)
      env['client.retries'] = 0
      status, headers, body = nil
      idempotent_exceptions = []
      begin
        dup_env = env.dup
        status, headers, body = @app.call(dup_env)
        raise HTTPException.new(status, headers, body) if IDEMPOTENT_HTTP_CODES.include?(status)
        env.merge!(dup_env)
        [status, headers, body]
      rescue *(IDEMPOTENT_ERROR_CLASSES + [HTTPException, Retryable]) => ie
        idempotent_exceptions << ie
        if env['client.retries'] > RETRY_LIMIT - 1
          raise(RetryLimitExceeded.new(idempotent_exceptions))
        else
          if retry?(status, env["REQUEST_METHOD"])
            env['client.retries'] += 1
            retry
          else
            raise
          end
        end
      end
    end

  private

  def retry?(response_status, request_method)
    RETRY_HTTP_CODES.include?(response_status) || request_method == "GET"
  end

  end
end
