# frozen_string_literal: true

require 'tempfile'
require 'test'

class TestEnvironmentTest < Test
  def test_env_config_client_connect_options
    config = <<~TOML
      [profile.cloud]
      address = "from-file.example:7233"
      namespace = "from-file-namespace"
      api_key = "from-file-api-key"

      [profile.cloud.tls]
      disabled = true

      [profile.cloud.grpc_meta]
      "x-test-source" = "from-file"
    TOML

    Tempfile.create(['temporal-test-config', '.toml']) do |file|
      file.write(config)
      file.flush
      with_test_env(
        'TEMPORAL_TEST_ENV_CONFIG_SERVER' => '1',
        'TEMPORAL_CONFIG_FILE' => file.path,
        'TEMPORAL_PROFILE' => 'cloud',
        'TEMPORAL_NAMESPACE' => 'from-environment-namespace',
        'TEMPORAL_TEST_CLIENT_TARGET_HOST' => 'legacy.example:7233'
      ) do
        args, kwargs = TestEnvironment.client_connect_options || raise
        assert_equal ['from-file.example:7233', 'from-environment-namespace'], args
        assert_equal 'from-file-api-key', kwargs[:api_key]
        assert_equal false, kwargs[:tls]
        assert_equal({ 'x-test-source' => 'from-file' }, kwargs[:rpc_metadata])

        client = Temporalio::Client.connect(args[0], args[1], **kwargs, lazy_connect: true)
        assert_equal 'from-file.example:7233', client.connection.target_host
        assert_equal 'from-environment-namespace', client.namespace
        assert_equal 'from-file-api-key', client.connection.api_key
        assert_equal false, client.connection.options.tls
      end
    end
  end

  def test_env_config_api_key_enables_tls_and_preserves_missing_namespace
    with_test_env(
      'TEMPORAL_TEST_ENV_CONFIG_SERVER' => '1',
      'TEMPORAL_CONFIG_FILE' => missing_config_path,
      'TEMPORAL_ADDRESS' => 'cloud.example:7233',
      'TEMPORAL_API_KEY' => 'api-key'
    ) do
      args, kwargs = TestEnvironment.client_connect_options || raise
      assert_equal ['cloud.example:7233', nil], args
      assert_equal 'api-key', kwargs[:api_key]
      assert_equal true, kwargs[:tls]
    end
  end

  def test_legacy_and_local_client_connect_options
    with_test_env(
      'TEMPORAL_TEST_ENV_CONFIG_SERVER' => '',
      'TEMPORAL_TEST_CLIENT_TARGET_HOST' => 'legacy.example:7233'
    ) do
      assert_equal [['legacy.example:7233', 'default'], {}], TestEnvironment.client_connect_options
    end

    with_test_env('TEMPORAL_TEST_ENV_CONFIG_SERVER' => '') do
      assert_nil TestEnvironment.client_connect_options
    end
  end

  private

  def with_test_env(values)
    original = ENV.to_h.select { |key, _| env_config_key?(key) }
    ENV.keys.select { |key| env_config_key?(key) }.each { |key| ENV.delete(key) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    ENV.keys.select { |key| env_config_key?(key) }.each { |key| ENV.delete(key) }
    original&.each { |key, value| ENV[key] = value }
  end

  def env_config_key?(key)
    %w[
      TEMPORAL_TEST_ENV_CONFIG_SERVER
      TEMPORAL_TEST_CLIENT_TARGET_HOST
      TEMPORAL_TEST_CLIENT_TARGET_NAMESPACE
      TEMPORAL_CONFIG_FILE
      TEMPORAL_PROFILE
      TEMPORAL_ADDRESS
      TEMPORAL_NAMESPACE
      TEMPORAL_API_KEY
      TEMPORAL_TLS
      TEMPORAL_CLIENT_AUTHORITY
      TEMPORAL_CODEC_ENDPOINT
      TEMPORAL_CODEC_AUTH
    ].include?(key) || key.start_with?('TEMPORAL_TLS_', 'TEMPORAL_GRPC_META_')
  end

  def missing_config_path
    File.join(__dir__ || '', "temporal-test-config-#{SecureRandom.uuid}.toml")
  end
end
