# frozen_string_literal: true

require_relative 'lib/temporalio/version'

Gem::Specification.new do |spec|
  spec.name = 'temporalio'
  spec.version = Temporalio::VERSION
  spec.authors = ['Temporal Technologies Inc']
  spec.email = ['sdk@temporal.io']

  spec.summary = 'Temporal.io Ruby SDK'
  spec.homepage = 'https://github.com/temporalio/sdk-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.required_rubygems_version = '>= 3.3.11'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/temporalio/sdk-ruby'

  spec.files = Dir['lib/**/*.rb', 'ext/**/*.*', 'Cargo.lock', 'Cargo.toml', 'Gemfile', 'Rakefile',
                   'temporalio.gemspec', 'LICENSE', 'README.md']

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.extensions = ['ext/Cargo.toml']
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_dependency 'google-protobuf', '>= 3.27.0'

  spec.add_development_dependency 'async'
  spec.add_development_dependency 'grpc', '>= 1.65.0.pre2'
  spec.add_development_dependency 'grpc-tools'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rake-compiler'
  spec.add_development_dependency 'rbs', '~> 3.5.3'
  spec.add_development_dependency 'rb_sys', '~> 0.9.63'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'steep', '~> 1.7.1'
  spec.add_development_dependency 'yard'
end
