# frozen_string_literal: true

require 'temporalio/client/connection'
require 'test'

class ClientConnectionTest < Test
  def test_connection_tls_enabled_by_default_when_api_key_provided
    # Test that TLS is enabled by default when API key is provided and tls is not configured
    connection = Temporalio::Client::Connection.new(
      target_host: 'localhost:7233',
      api_key: 'test-api-key',
      lazy_connect: true
    )

    # TLS should be auto-enabled when api_key is provided and tls not explicitly set
    assert_equal true, connection.options.tls
  end

  def test_connection_tls_can_be_explicitly_disabled_with_api_key
    # Test that TLS can be explicitly disabled even when API key is provided
    connection = Temporalio::Client::Connection.new(
      target_host: 'localhost:7233',
      api_key: 'test-api-key',
      tls: false,
      lazy_connect: true
    )

    # TLS should remain disabled when explicitly set to false
    assert_equal false, connection.options.tls
  end

  def test_connection_explicit_tls_config_preserved_with_api_key
    # Test that explicit TLS configuration is preserved regardless of API key
    tls_options = Temporalio::Client::Connection::TLSOptions.new(
      server_root_ca_cert: 'test-cert',
      domain: 'test-domain'
    )

    connection = Temporalio::Client::Connection.new(
      target_host: 'localhost:7233',
      api_key: 'test-api-key',
      tls: tls_options,
      lazy_connect: true
    )

    # Explicit TLS config should be preserved
    assert_equal tls_options, connection.options.tls
  end
end
