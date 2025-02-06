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

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/temporalio/sdk-ruby'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'Cargo.*',
                   'temporalio.gemspec', 'Gemfile', 'Rakefile', '.yardopts']

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.extensions = ['ext/Cargo.toml']
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_dependency 'google-protobuf', '>= 3.25.0'
end
