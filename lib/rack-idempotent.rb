require "rack-idempotent/version"

module Rack
  class Idempotent
    def initialize(app)
      @app= app
    end

    def call(env)
      env['client.retries'] = 0
      begin
        @app.call(env)
      rescue Errno::ETIMEDOUT
        env['client.retries'] += 1
        retry
      end
    end
  end
end
