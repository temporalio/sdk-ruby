require_relative './lib/temporal/version'

Gem::Specification.new do |spec|
  spec.name          = 'temporal-ruby'
  spec.version       = Temporal::VERSION
  spec.summary       = 'Temporal.io Ruby SDK'
  spec.description   = 'An SDK for implementing Temporal.io workflows and activities in Ruby'
  spec.homepage      = 'https://github.com/temporalio/sdk-ruby'
  spec.licenses      = ['MIT']

  spec.authors       = ['Anthony D']
  spec.email         = ['anthony@temporal.io']

  spec.require_paths = ['lib']
  spec.files         = Dir["{lib}/**/*.*"] + %w(temporal.gemspec Gemfile LICENSE README.md)
end
