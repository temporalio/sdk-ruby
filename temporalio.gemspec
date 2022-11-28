require_relative './lib/temporal/version'

Gem::Specification.new do |spec|
  spec.name          = 'temporalio'
  spec.version       = Temporal::VERSION
  spec.summary       = 'Temporal.io Ruby SDK'
  spec.description   = 'An SDK for implementing Temporal.io workflows and activities in Ruby'
  spec.homepage      = 'https://github.com/temporalio/sdk-ruby'
  spec.licenses      = ['MIT']

  spec.authors       = ['Anthony D']
  spec.email         = ['anthony@temporal.io']

  spec.require_paths = ['lib']
  spec.extensions    = ['ext/Rakefile']

  spec.files =
    Dir['lib/**/*.*'] +
    Dir['bridge/**/*.*'].reject { |x| x.include?('/target/') } +
    %w[ext/Rakefile temporalio.gemspec Gemfile LICENSE README.md]

  # Limited by async. While we support both v1 and v2, we only allow Ruby >= 3
  # since async v1 with Ruby 2 has a blocking behaviour (despite identical interface):
  # https://github.com/socketry/async/discussions/108#discussioncomment-541788
  spec.required_ruby_version = '>= 3.0.2'

  spec.add_dependency 'async' # Fiber-based reactor. Open-ended to allow Ruby 3.1+ to use v2
  spec.add_dependency 'google-protobuf', '~> 3.21.1' # Protobuf
  spec.add_dependency 'rexml', '~> 3.2.5' # Implicitly required by thermite
  spec.add_dependency 'rutie', '~> 0.0.4' # Rust bindings
  spec.add_dependency 'thermite', '~> 0.13.0' # For compiling Rust ext

  spec.add_development_dependency 'grpc' # Ruby GRPC for the mock server
  spec.add_development_dependency 'grpc-tools' # GRPC generator for the mock server
  spec.add_development_dependency 'protobuf' # Ruby implementation of protobufs (for rbs_protobuf)
  spec.add_development_dependency 'pry' # Debugger
  spec.add_development_dependency 'rake' # rake tasks
  spec.add_development_dependency 'rbs_protobuf' # RBS generator for protobufs
  spec.add_development_dependency 'rspec' # specs
  spec.add_development_dependency 'rubocop' # linter
  spec.add_development_dependency 'rubocop-rspec' # spec linter
  spec.add_development_dependency 'steep' # type checker
  spec.add_development_dependency 'typeprof' # type generator
  spec.add_development_dependency 'yard' # docs
end
