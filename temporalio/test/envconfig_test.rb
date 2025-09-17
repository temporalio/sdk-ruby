# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'temporalio/client'
require 'temporalio/env_config'
require 'tmpdir'
require_relative 'test'

class EnvConfigTest < Test
  # A base TOML config with a default and a custom profile
  TOML_CONFIG_BASE = <<~TOML
    [profile.default]
    address = "default-address"
    namespace = "default-namespace"

    [profile.custom]
    address = "custom-address"
    namespace = "custom-namespace"
    api_key = "custom-api-key"
    [profile.custom.tls]
    server_name = "custom-server-name"
    [profile.custom.grpc_meta]
    custom-header = "custom-value"
  TOML

  # A TOML config with an unrecognized key for strict testing
  TOML_CONFIG_STRICT_FAIL = <<~TOML
    [profile.default]
    address = "default-address"
    unrecognized_field = "should-fail"
  TOML

  # Malformed TOML for error testing
  TOML_CONFIG_MALFORMED = 'this is not valid toml'

  # A TOML config for testing detailed TLS options
  TOML_CONFIG_TLS_DETAILED = <<~TOML
    [profile.tls_disabled]
    address = "localhost:1234"
    [profile.tls_disabled.tls]
    disabled = true
    server_name = "should-be-ignored"

    [profile.tls_with_certs]
    address = "localhost:5678"
    [profile.tls_with_certs.tls]
    server_name = "custom-server"
    server_ca_cert_data = "ca-pem-data"
    client_cert_data = "client-crt-data"
    client_key_data = "client-key-data"
  TOML

  # TOML config for metadata normalization testing
  TOML_CONFIG_GRPC_META = <<~TOML
    [profile.default]
    address = "localhost:7233"
    namespace = "default"

    [profile.default.grpc_meta]
    "Custom-Header" = "custom-value"
    "ANOTHER_HEADER_KEY" = "another-value"
    "mixed_Case-header" = "mixed-value"
  TOML

  # =============================================================================
  # PROFILE LOADING TESTS (6 tests)
  # =============================================================================

  def test_load_profile_from_file_default
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      profile = Temporalio::EnvConfig::ClientConfigProfile.load(config_source: Pathname.new(config_file))
      assert_equal 'default-address', profile.address
      assert_equal 'default-namespace', profile.namespace
      assert_nil profile.tls
      refute_includes profile.grpc_meta, 'custom-header'

      args, kwargs = profile.to_client_connect_options
      assert_equal 'default-address', args[0]
      assert_equal 'default-namespace', args[1]
      assert_nil kwargs[:tls]
      rpc_meta = kwargs[:rpc_metadata]
      if rpc_meta.nil?
        assert_nil rpc_meta
      else
        refute_includes rpc_meta, 'custom-header'
      end
    end
  end

  def test_load_profile_from_file_custom
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      profile = Temporalio::EnvConfig::ClientConfigProfile.load(config_source: Pathname.new(config_file),
                                                                profile: 'custom')
      assert_equal 'custom-address', profile.address
      assert_equal 'custom-namespace', profile.namespace
      refute_nil profile.tls
      assert_equal 'custom-server-name', profile.tls.server_name # steep:ignore
      assert_equal 'custom-value', profile.grpc_meta['custom-header']

      args, kwargs = profile.to_client_connect_options
      assert_equal 'custom-address', args[0]
      assert_equal 'custom-namespace', args[1]
      tls_config = kwargs[:tls]
      assert_instance_of Temporalio::Client::Connection::TLSOptions, tls_config
      assert_equal 'custom-server-name', tls_config.domain
      rpc_metadata = kwargs[:rpc_metadata]
      refute_nil rpc_metadata
      assert_equal 'custom-value', rpc_metadata['custom-header']
    end
  end

  def test_load_profile_from_data_default
    profile = Temporalio::EnvConfig::ClientConfigProfile.load(config_source: TOML_CONFIG_BASE)
    assert_equal 'default-address', profile.address
    assert_equal 'default-namespace', profile.namespace
    assert_nil profile.tls

    args, kwargs = profile.to_client_connect_options
    assert_equal 'default-address', args[0]
    assert_equal 'default-namespace', args[1]
    assert_nil kwargs[:tls]
  end

  def test_load_profile_from_data_custom
    profile = Temporalio::EnvConfig::ClientConfigProfile.load(config_source: TOML_CONFIG_BASE, profile: 'custom')
    assert_equal 'custom-address', profile.address
    assert_equal 'custom-namespace', profile.namespace
    refute_nil profile.tls
    assert_equal 'custom-server-name', profile.tls.server_name # steep:ignore
    assert_equal 'custom-value', profile.grpc_meta['custom-header']

    args, kwargs = profile.to_client_connect_options
    assert_equal 'custom-address', args[0]
    assert_equal 'custom-namespace', args[1]
    tls_config = kwargs[:tls]
    assert_instance_of Temporalio::Client::Connection::TLSOptions, tls_config
    assert_equal 'custom-server-name', tls_config.domain
    rpc_metadata = kwargs[:rpc_metadata]
    refute_nil rpc_metadata
    assert_equal 'custom-value', rpc_metadata['custom-header']
  end

  def test_load_profile_from_data_env_overrides
    env = {
      'TEMPORAL_ADDRESS' => 'env-address',
      'TEMPORAL_NAMESPACE' => 'env-namespace'
    }
    profile = Temporalio::EnvConfig::ClientConfigProfile.load(
      config_source: TOML_CONFIG_BASE, profile: 'custom', override_env_vars: env
    )
    assert_equal 'env-address', profile.address
    assert_equal 'env-namespace', profile.namespace

    args, = profile.to_client_connect_options
    assert_equal 'env-address', args[0]
    assert_equal 'env-namespace', args[1]
  end

  def test_load_profile_env_overrides
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      env = {
        'TEMPORAL_ADDRESS' => 'env-address',
        'TEMPORAL_NAMESPACE' => 'env-namespace',
        'TEMPORAL_API_KEY' => 'env-api-key',
        'TEMPORAL_TLS_SERVER_NAME' => 'env-server-name'
      }
      profile = Temporalio::EnvConfig::ClientConfigProfile.load(
        config_source: Pathname.new(config_file), profile: 'custom', override_env_vars: env
      )
      assert_equal 'env-address', profile.address
      assert_equal 'env-namespace', profile.namespace
      assert_equal 'env-api-key', profile.api_key
      refute_nil profile.tls
      assert_equal 'env-server-name', profile.tls.server_name # steep:ignore

      args, kwargs = profile.to_client_connect_options
      assert_equal 'env-address', args[0]
      assert_equal 'env-namespace', args[1]
      assert_equal 'env-api-key', kwargs[:api_key]
      tls_config = kwargs[:tls]
      assert_instance_of Temporalio::Client::Connection::TLSOptions, tls_config
      assert_equal 'env-server-name', tls_config.domain
    end
  end

  # =============================================================================
  # ENVIRONMENT VARIABLES TESTS (4 tests)
  # =============================================================================

  def test_load_profile_grpc_meta_env_overrides
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      env = {
        # This should override the value in the file
        'TEMPORAL_GRPC_META_CUSTOM_HEADER' => 'env-value',
        # This should add a new header
        'TEMPORAL_GRPC_META_ANOTHER_HEADER' => 'another-value'
      }
      profile = Temporalio::EnvConfig::ClientConfigProfile.load(
        config_source: Pathname.new(config_file), profile: 'custom', override_env_vars: env
      )
      assert_equal 'env-value', profile.grpc_meta['custom-header']
      assert_equal 'another-value', profile.grpc_meta['another-header']

      _, kwargs = profile.to_client_connect_options
      rpc_metadata = kwargs[:rpc_metadata]
      refute_nil rpc_metadata
      assert_equal 'env-value', rpc_metadata['custom-header']
      assert_equal 'another-value', rpc_metadata['another-header']
    end
  end

  def test_grpc_metadata_normalization_from_toml
    profile = Temporalio::EnvConfig::ClientConfigProfile.load(config_source: TOML_CONFIG_GRPC_META)

    # Keys should be normalized: uppercase -> lowercase, underscores -> hyphens
    assert_equal 'custom-value', profile.grpc_meta['custom-header']
    assert_equal 'another-value', profile.grpc_meta['another-header-key']
    assert_equal 'mixed-value', profile.grpc_meta['mixed-case-header']

    # Original case variations should not exist
    refute_includes profile.grpc_meta, 'Custom-Header'
    refute_includes profile.grpc_meta, 'ANOTHER_HEADER_KEY'
    refute_includes profile.grpc_meta, 'mixed_Case-header'

    _, kwargs = profile.to_client_connect_options
    rpc_metadata = kwargs[:rpc_metadata]
    refute_nil rpc_metadata
    assert_equal 'custom-value', rpc_metadata['custom-header']
    assert_equal 'another-value', rpc_metadata['another-header-key']
  end

  def test_grpc_metadata_deletion_via_empty_env_value
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      env = {
        # Empty value should remove the header
        'TEMPORAL_GRPC_META_CUSTOM_HEADER' => '',
        # Non-empty value should set the header
        'TEMPORAL_GRPC_META_NEW_HEADER' => 'new-value'
      }
      profile = Temporalio::EnvConfig::ClientConfigProfile.load(
        config_source: Pathname.new(config_file), profile: 'custom', override_env_vars: env
      )

      # custom-header should be removed by empty env value
      refute_includes profile.grpc_meta, 'custom-header'
      # new-header should be added
      assert_equal 'new-value', profile.grpc_meta['new-header']

      _, kwargs = profile.to_client_connect_options
      rpc_metadata = kwargs[:rpc_metadata]
      if rpc_metadata && !rpc_metadata.empty?
        refute_includes rpc_metadata, 'custom-header'
        assert_equal 'new-value', rpc_metadata['new-header']
      end
    end
  end

  def test_load_profile_disable_env
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      env = { 'TEMPORAL_ADDRESS' => 'env-address' }
      profile = Temporalio::EnvConfig::ClientConfigProfile.load(
        config_source: Pathname.new(config_file), override_env_vars: env, disable_env: true
      )
      assert_equal 'default-address', profile.address

      args, = profile.to_client_connect_options
      assert_equal 'default-address', args[0]
    end
  end

  # =============================================================================
  # CONTROL FLAGS TESTS (3 tests)
  # =============================================================================

  def test_load_profile_disable_file
    env = { 'TEMPORAL_ADDRESS' => 'env-address' }
    profile = Temporalio::EnvConfig::ClientConfigProfile.load(disable_file: true, override_env_vars: env)
    assert_equal 'env-address', profile.address

    args, = profile.to_client_connect_options
    assert_equal 'env-address', args[0]
  end

  def test_load_profiles_no_env_override
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      env = {
        'TEMPORAL_CONFIG_FILE' => config_file,
        'TEMPORAL_ADDRESS' => 'env-address' # This should be ignored for profiles loading
      }
      client_config = Temporalio::EnvConfig::ClientConfig.load(override_env_vars: env)
      args, = client_config.profiles['default'].to_client_connect_options
      assert_equal 'default-address', args[0]
    end
  end

  def test_disables_raise_error
    assert_raises(Temporalio::Internal::Bridge::Error) do
      Temporalio::EnvConfig::ClientConfigProfile.load(disable_file: true, disable_env: true)
    end
  end

  # =============================================================================
  # CONFIG DISCOVERY TESTS (6 tests)
  # =============================================================================

  def test_load_profiles_from_file_all
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      client_config = Temporalio::EnvConfig::ClientConfig.load(config_source: Pathname.new(config_file))
      assert_equal 2, client_config.profiles.size
      assert_includes client_config.profiles, 'default'
      assert_includes client_config.profiles, 'custom'
      # Check that we can convert to a connect config
      args, = client_config.profiles['default'].to_client_connect_options
      assert_equal 'default-address', args[0]
    end
  end

  def test_load_profiles_from_data_all
    client_config = Temporalio::EnvConfig::ClientConfig.load(config_source: TOML_CONFIG_BASE)
    assert_equal 2, client_config.profiles.size
    args, = client_config.profiles['custom'].to_client_connect_options
    assert_equal 'custom-address', args[0]
  end

  def test_load_profiles_no_config_file
    client_config = Temporalio::EnvConfig::ClientConfig.load(override_env_vars: {})
    assert_empty client_config.profiles
  end

  def test_load_profiles_discovery
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      env = { 'TEMPORAL_CONFIG_FILE' => config_file }
      client_config = Temporalio::EnvConfig::ClientConfig.load(override_env_vars: env)
      assert_includes client_config.profiles, 'default'
    end
  end

  def test_default_profile_not_found_returns_empty_profile
    toml = <<~TOML
      [profile.existing]
      address = "my-address"
    TOML
    profile = Temporalio::EnvConfig::ClientConfigProfile.load(config_source: toml)
    assert_nil profile.address
    assert_nil profile.namespace
    assert_nil profile.api_key
    assert_empty profile.grpc_meta
    assert_nil profile.tls
  end

  # =============================================================================
  # TLS CONFIGURATION TESTS (7 tests)
  # =============================================================================

  def test_load_profile_api_key_enables_tls
    config_toml = "[profile.default]\naddress = 'some-host:1234'\napi_key = 'my-key'"
    profile = Temporalio::EnvConfig::ClientConfigProfile.load(config_source: config_toml)
    assert_equal 'my-key', profile.api_key
    # No TLS object should have been created
    assert_nil profile.tls

    _, kwargs = profile.to_client_connect_options
    # Expect to_client_connect_config call to set TLS to True
    # due to presence of api key.
    assert_equal true, kwargs[:tls]
    assert_equal 'my-key', kwargs[:api_key]
  end

  def test_load_profile_tls_options
    # Test with TLS disabled
    profile_disabled = Temporalio::EnvConfig::ClientConfigProfile.load(
      config_source: TOML_CONFIG_TLS_DETAILED, profile: 'tls_disabled'
    )
    refute_nil profile_disabled.tls
    assert profile_disabled.tls.disabled # steep:ignore

    _, kwargs_disabled = profile_disabled.to_client_connect_options
    assert_equal false, kwargs_disabled[:tls]

    # Test with TLS certs
    profile_certs = Temporalio::EnvConfig::ClientConfigProfile.load(
      config_source: TOML_CONFIG_TLS_DETAILED, profile: 'tls_with_certs'
    )
    refute_nil profile_certs.tls
    assert_equal 'custom-server', profile_certs.tls.server_name # steep:ignore
    refute_nil profile_certs.tls.server_root_ca_cert # steep:ignore
    assert_equal 'ca-pem-data', profile_certs.tls.server_root_ca_cert # steep:ignore
    refute_nil profile_certs.tls.client_cert # steep:ignore
    assert_equal 'client-crt-data', profile_certs.tls.client_cert # steep:ignore
    refute_nil profile_certs.tls.client_private_key # steep:ignore
    assert_equal 'client-key-data', profile_certs.tls.client_private_key # steep:ignore

    _, kwargs_certs = profile_certs.to_client_connect_options
    tls_config_certs = kwargs_certs[:tls]
    assert_instance_of Temporalio::Client::Connection::TLSOptions, tls_config_certs
    assert_equal 'custom-server', tls_config_certs.domain
    assert_equal 'ca-pem-data', tls_config_certs.server_root_ca_cert
    assert_equal 'client-crt-data', tls_config_certs.client_cert
    assert_equal 'client-key-data', tls_config_certs.client_private_key
  end

  def test_load_profile_tls_from_paths
    Dir.mktmpdir do |tmpdir| # steep:ignore
      # Create dummy cert files
      ca_pem_path = File.join(tmpdir, 'ca.pem')
      client_crt_path = File.join(tmpdir, 'client.crt')
      client_key_path = File.join(tmpdir, 'client.key')

      File.write(ca_pem_path, 'ca-pem-data')
      File.write(client_crt_path, 'client-crt-data')
      File.write(client_key_path, 'client-key-data')

      toml_config = <<~TOML
        [profile.default]
        address = "localhost:5678"
        [profile.default.tls]
        server_name = "custom-server"
        server_ca_cert_path = "#{ca_pem_path}"
        client_cert_path = "#{client_crt_path}"
        client_key_path = "#{client_key_path}"
      TOML

      profile = Temporalio::EnvConfig::ClientConfigProfile.load(config_source: toml_config)
      refute_nil profile.tls
      assert_equal 'custom-server', profile.tls.server_name # steep:ignore
      refute_nil profile.tls.server_root_ca_cert # steep:ignore
      assert_equal Pathname.new(ca_pem_path), profile.tls.server_root_ca_cert # steep:ignore
      refute_nil profile.tls.client_cert # steep:ignore
      assert_equal Pathname.new(client_crt_path), profile.tls.client_cert # steep:ignore
      refute_nil profile.tls.client_private_key # steep:ignore
      assert_equal Pathname.new(client_key_path), profile.tls.client_private_key # steep:ignore

      _, kwargs = profile.to_client_connect_options
      tls_config = kwargs[:tls]
      assert_instance_of Temporalio::Client::Connection::TLSOptions, tls_config
      assert_equal 'custom-server', tls_config.domain
      assert_equal 'ca-pem-data', tls_config.server_root_ca_cert
      assert_equal 'client-crt-data', tls_config.client_cert
      assert_equal 'client-key-data', tls_config.client_private_key
    end
  end

  def test_load_profile_conflicting_cert_source_fails
    toml_config = <<~TOML
      [profile.default]
      address = "localhost:5678"
      [profile.default.tls]
      client_cert_path = "/path/to/cert"
      client_cert_data = "cert-data"
    TOML
    assert_raises(Temporalio::Internal::Bridge::Error) do
      Temporalio::EnvConfig::ClientConfigProfile.load(config_source: toml_config)
    end
  end

  def test_tls_conflict_across_sources_path_in_toml_data_in_env
    toml_config = <<~TOML
      [profile.default]
      address = "localhost:7233"
      [profile.default.tls]
      client_cert_path = "/path/to/cert"
    TOML

    env = {
      'TEMPORAL_TLS_CLIENT_CERT_DATA' => 'cert-data-from-env'
    }

    assert_raises(Temporalio::Internal::Bridge::Error) do
      Temporalio::EnvConfig::ClientConfigProfile.load(
        config_source: toml_config,
        override_env_vars: env
      )
    end
  end

  def test_tls_conflict_across_sources_data_in_toml_path_in_env
    toml_config = <<~TOML
      [profile.default]
      address = "localhost:7233"
      [profile.default.tls]
      client_cert_data = "cert-data-from-toml"
    TOML

    env = {
      'TEMPORAL_TLS_CLIENT_CERT_PATH' => '/path/from/env'
    }

    assert_raises(Temporalio::Internal::Bridge::Error) do
      Temporalio::EnvConfig::ClientConfigProfile.load(
        config_source: toml_config,
        override_env_vars: env
      )
    end
  end

  # =============================================================================
  # ERROR HANDLING TESTS (4 tests)
  # =============================================================================

  def test_load_profile_not_found
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      assert_raises(Temporalio::Internal::Bridge::Error) do
        Temporalio::EnvConfig::ClientConfigProfile.load(config_source: Pathname.new(config_file),
                                                        profile: 'nonexistent')
      end
    end
  end

  def test_load_profiles_strict_mode_fail
    with_temp_config_file(TOML_CONFIG_STRICT_FAIL) do |config_file|
      assert_raises(Temporalio::Internal::Bridge::Error) do
        Temporalio::EnvConfig::ClientConfig.load(config_source: Pathname.new(config_file), config_file_strict: true)
      end
    end
  end

  def test_load_profile_strict_mode_fail
    with_temp_config_file(TOML_CONFIG_STRICT_FAIL) do |config_file|
      assert_raises(Temporalio::Internal::Bridge::Error) do
        Temporalio::EnvConfig::ClientConfigProfile.load(config_source: Pathname.new(config_file),
                                                        config_file_strict: true)
      end
    end
  end

  def test_load_profiles_from_data_malformed
    assert_raises(Temporalio::Internal::Bridge::Error) do
      Temporalio::EnvConfig::ClientConfig.load(config_source: TOML_CONFIG_MALFORMED)
    end
  end

  # =============================================================================
  # SERIALIZATION TESTS (3 tests)
  # =============================================================================

  def test_client_config_profile_to_from_dict
    # Profile with all fields
    profile = Temporalio::EnvConfig::ClientConfigProfile.new(
      address: 'some-address',
      namespace: 'some-namespace',
      api_key: 'some-api-key',
      tls: Temporalio::EnvConfig::ClientConfigTLS.new(
        disabled: false,
        server_name: 'some-server-name',
        server_root_ca_cert: 'ca-cert-data',
        client_cert: Pathname.new('/path/to/client.crt'),
        client_private_key: 'client-key-data'
      ),
      grpc_meta: { 'some-header' => 'some-value' }
    )

    profile_hash = profile.to_h

    # Check hash representation. disabled=false is now included since it was explicitly set.
    expected_hash = {
      address: 'some-address',
      namespace: 'some-namespace',
      api_key: 'some-api-key',
      tls: {
        disabled: false,
        server_name: 'some-server-name',
        server_ca_cert: { data: 'ca-cert-data' },
        client_cert: { path: '/path/to/client.crt' },
        client_key: { data: 'client-key-data' }
      },
      grpc_meta: { 'some-header' => 'some-value' }
    }
    assert_equal expected_hash, profile_hash

    # Convert back to profile
    new_profile = Temporalio::EnvConfig::ClientConfigProfile.from_h(profile_hash)

    # We expect the new profile to be the same
    assert_equal profile.address, new_profile.address
    assert_equal profile.namespace, new_profile.namespace
    assert_equal profile.api_key, new_profile.api_key
    assert_equal profile.grpc_meta, new_profile.grpc_meta

    # Test with minimal profile
    profile_minimal = Temporalio::EnvConfig::ClientConfigProfile.new
    profile_minimal_hash = profile_minimal.to_h
    assert_empty profile_minimal_hash
    new_profile_minimal = Temporalio::EnvConfig::ClientConfigProfile.from_h(profile_minimal_hash)
    assert_nil profile_minimal.address
    assert_nil new_profile_minimal.address
  end

  def test_client_config_to_from_dict
    # Config with multiple profiles
    profile1 = Temporalio::EnvConfig::ClientConfigProfile.new(
      address: 'some-address',
      namespace: 'some-namespace'
    )
    profile2 = Temporalio::EnvConfig::ClientConfigProfile.new(
      address: 'another-address',
      tls: Temporalio::EnvConfig::ClientConfigTLS.new(server_name: 'some-server-name'),
      grpc_meta: { 'some-header' => 'some-value' }
    )
    config = Temporalio::EnvConfig::ClientConfig.new(profiles: {
                                                       'default' => profile1,
                                                       'custom' => profile2
                                                     })

    config_hash = config.to_h

    expected_hash = {
      'default' => {
        address: 'some-address',
        namespace: 'some-namespace'
      },
      'custom' => {
        address: 'another-address',
        tls: { server_name: 'some-server-name' },
        grpc_meta: { 'some-header' => 'some-value' }
      }
    }
    assert_equal expected_hash, config_hash

    # Convert back to config
    new_config = Temporalio::EnvConfig::ClientConfig.from_h(config_hash)
    assert_equal config.profiles.keys, new_config.profiles.keys

    # Test empty config
    empty_config = Temporalio::EnvConfig::ClientConfig.new(profiles: {})
    empty_config_hash = empty_config.to_h
    assert_empty empty_config_hash
    new_empty_config = Temporalio::EnvConfig::ClientConfig.from_h(empty_config_hash)
    assert_empty new_empty_config.profiles
  end

  def test_read_source_from_string_content
    # Test that read_source correctly handles string content
    profile = Temporalio::EnvConfig::ClientConfigProfile.new(
      address: 'localhost:1234',
      tls: Temporalio::EnvConfig::ClientConfigTLS.new(client_cert: 'string-as-cert-content')
    )
    _, kwargs = profile.to_client_connect_options
    tls_config = kwargs[:tls]
    assert_instance_of Temporalio::Client::Connection::TLSOptions, tls_config
    assert_equal 'string-as-cert-content', tls_config.client_cert
  end

  # =============================================================================
  # INTEGRATION/E2E TESTS (2 tests)
  # =============================================================================

  def test_load_client_connect_options_convenience_api
    with_temp_config_file(TOML_CONFIG_BASE) do |config_file|
      # Test default profile with file
      args, = Temporalio::EnvConfig::ClientConfig.load_client_connect_options(
        config_source: Pathname.new(config_file)
      )
      assert_equal 'default-address', args[0]
      assert_equal 'default-namespace', args[1]

      # Test with environment overrides
      env = { 'TEMPORAL_NAMESPACE' => 'env-override-namespace' }
      args_with_env, = Temporalio::EnvConfig::ClientConfig.load_client_connect_options(
        config_source: Pathname.new(config_file),
        override_env_vars: env
      )
      assert_equal 'default-address', args_with_env[0]
      assert_equal 'env-override-namespace', args_with_env[1]

      # Test with specific profile
      args_custom, kwargs_custom = Temporalio::EnvConfig::ClientConfig.load_client_connect_options(
        profile: 'custom',
        config_source: Pathname.new(config_file)
      )
      assert_equal 'custom-address', args_custom[0]
      assert_equal 'custom-namespace', args_custom[1]
      assert_equal 'custom-api-key', kwargs_custom[:api_key]
    end
  end

  def test_load_client_connect_options_e2e_validation
    # Test comprehensive end-to-end configuration loading with all features
    toml_content = <<~TOML
      [profile.production]
      address = "prod.temporal.com:443"
      namespace = "production-ns"
      api_key = "prod-api-key"

      [profile.production.tls]
      server_name = "prod.temporal.com"
      server_ca_cert_data = "prod-ca-cert"

      [profile.production.grpc_meta]
      authorization = "Bearer prod-token"
      "x-custom-header" = "prod-value"
    TOML

    env_overrides = {
      'TEMPORAL_GRPC_META_X_ENVIRONMENT' => 'production',
      'TEMPORAL_TLS_SERVER_NAME' => 'override.temporal.com'
    }

    args, kwargs = Temporalio::EnvConfig::ClientConfig.load_client_connect_options(
      profile: 'production',
      config_source: toml_content,
      override_env_vars: env_overrides
    )

    # Validate all configuration aspects
    assert_equal 'prod.temporal.com:443', args[0]
    assert_equal 'production-ns', args[1]
    assert_equal 'prod-api-key', kwargs[:api_key]

    # TLS configuration (API key should auto-enable TLS)
    refute_nil kwargs[:tls]
    tls_config = kwargs[:tls]
    assert_equal 'override.temporal.com', tls_config.domain # Env override
    assert_equal 'prod-ca-cert', tls_config.server_root_ca_cert

    # gRPC metadata with normalization and env overrides
    refute_nil kwargs[:rpc_metadata]
    rpc_metadata = kwargs[:rpc_metadata]
    assert_equal 'Bearer prod-token', rpc_metadata['authorization']
    assert_equal 'prod-value', rpc_metadata['x-custom-header']
    assert_equal 'production', rpc_metadata['x-environment'] # From env
  end

  # =============================================================================
  # END-TO-END CLIENT CONNECTION TESTS (4 tests)
  # =============================================================================

  def test_e2e_basic_development_profile_client_connection
    toml_content = <<~TOML
      [profile.development]
      address = "localhost:7233"
      namespace = "dev-namespace"

      [profile.development.grpc_meta]
      "x-test-source" = "envconfig-ruby-dev"
    TOML

    profile = Temporalio::EnvConfig::ClientConfigProfile.load(
      profile: 'development',
      config_source: toml_content
    )

    args, kwargs = profile.to_client_connect_options

    # Create actual Temporal client using envconfig
    client = Temporalio::Client.connect(
      args[0],
      args[1],
      api_key: kwargs[:api_key],
      tls: kwargs[:tls],
      rpc_metadata: profile.grpc_meta,
      lazy_connect: true
    )

    # Verify client configuration matches envconfig
    assert_equal 'localhost:7233', client.connection.target_host
    assert_equal 'dev-namespace', client.namespace
    assert_equal 'envconfig-ruby-dev', client.connection.options.rpc_metadata['x-test-source']
  end

  def test_e2e_production_tls_api_key_client_connection
    toml_content = <<~TOML
      [profile.production]
      address = "prod.tmprl.cloud:443"
      namespace = "production-namespace"
      api_key = "prod-api-key-123"

      [profile.production.tls]
      server_name = "prod.tmprl.cloud"

      [profile.production.grpc_meta]
      authorization = "Bearer prod-token"
      "x-environment" = "production"
    TOML

    profile = Temporalio::EnvConfig::ClientConfigProfile.load(
      profile: 'production',
      config_source: toml_content
    )

    args, kwargs = profile.to_client_connect_options

    # Create TLS-enabled client with API key
    client = Temporalio::Client.connect(
      args[0],
      args[1],
      api_key: kwargs[:api_key],
      tls: kwargs[:tls],
      rpc_metadata: profile.grpc_meta,
      lazy_connect: true
    )

    # Verify production configuration
    assert_equal 'prod.tmprl.cloud:443', client.connection.target_host
    assert_equal 'production-namespace', client.namespace
    assert_equal 'prod-api-key-123', client.connection.options.api_key
    refute_nil client.connection.options.tls # TLS should be enabled with API key
    assert_equal 'Bearer prod-token', client.connection.options.rpc_metadata['authorization']
    assert_equal 'production', client.connection.options.rpc_metadata['x-environment']
  end

  def test_e2e_environment_overrides_client_connection
    toml_content = <<~TOML
      [profile.staging]
      address = "staging.temporal.com:443"
      namespace = "staging-namespace"

      [profile.staging.grpc_meta]
      "x-deployment" = "staging"
      authorization = "Bearer staging-token"
    TOML

    env_overrides = {
      'TEMPORAL_ADDRESS' => 'override.temporal.com:443',
      'TEMPORAL_NAMESPACE' => 'override-namespace',
      'TEMPORAL_GRPC_META_X_DEPLOYMENT' => 'canary',
      'TEMPORAL_GRPC_META_AUTHORIZATION' => 'Bearer override-token'
    }

    profile = Temporalio::EnvConfig::ClientConfigProfile.load(
      profile: 'staging',
      config_source: toml_content,
      override_env_vars: env_overrides
    )

    args, = profile.to_client_connect_options

    # Create client with environment overrides
    client = Temporalio::Client.connect(
      args[0],
      args[1],
      rpc_metadata: profile.grpc_meta,
      lazy_connect: true
    )

    # Verify environment overrides took effect
    assert_equal 'override.temporal.com:443', client.connection.target_host
    assert_equal 'override-namespace', client.namespace
    assert_equal 'canary', client.connection.options.rpc_metadata['x-deployment']
    assert_equal 'Bearer override-token', client.connection.options.rpc_metadata['authorization']
  end

  def test_e2e_multi_profile_different_client_connections
    toml_content = <<~TOML
      [profile.development]
      address = "localhost:7233"
      namespace = "dev"

      [profile.production]
      address = "prod.tmprl.cloud:443"
      namespace = "prod"
      api_key = "prod-key"

      [profile.production.tls]
      server_name = "prod.tmprl.cloud"
    TOML

    # Load and create development client
    dev_profile = Temporalio::EnvConfig::ClientConfigProfile.load(
      profile: 'development',
      config_source: toml_content
    )

    args_dev, kwargs_dev = dev_profile.to_client_connect_options
    dev_client = Temporalio::Client.connect(
      args_dev[0],
      args_dev[1],
      api_key: kwargs_dev[:api_key],
      tls: kwargs_dev[:tls],
      lazy_connect: true
    )

    # Load and create production client
    prod_profile = Temporalio::EnvConfig::ClientConfigProfile.load(
      profile: 'production',
      config_source: toml_content
    )

    args_prod, kwargs_prod = prod_profile.to_client_connect_options
    prod_client = Temporalio::Client.connect(
      args_prod[0],
      args_prod[1],
      api_key: kwargs_prod[:api_key],
      tls: kwargs_prod[:tls],
      lazy_connect: true
    )

    # Verify different configurations for each client
    assert_equal 'localhost:7233', dev_client.connection.target_host
    assert_equal 'dev', dev_client.namespace
    assert_nil dev_client.connection.options.api_key
    assert_nil dev_client.connection.options.tls

    assert_equal 'prod.tmprl.cloud:443', prod_client.connection.target_host
    assert_equal 'prod', prod_client.namespace
    assert_equal 'prod-key', prod_client.connection.options.api_key
    refute_nil prod_client.connection.options.tls # TLS enabled with API key
  end

  private

  def with_temp_config_file(content)
    Dir.mktmpdir do |tmpdir| # steep:ignore
      config_file = File.join(tmpdir, 'config.toml')
      File.write(config_file, content)
      yield config_file
    end
  end
end
