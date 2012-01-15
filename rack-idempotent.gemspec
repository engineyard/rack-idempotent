# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rack-idempotent/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ines Sombra"]
  gem.email         = ["isombra@engineyard.com"]
  gem.description   = %q{Retry logic for rack-client}
  gem.summary       = %q{Retry logic for rack-client}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "rack-idempotent"
  gem.require_paths = ["lib"]
  gem.version       = Rack::Idempotent::VERSION
end
