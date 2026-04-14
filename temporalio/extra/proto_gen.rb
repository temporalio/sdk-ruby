# frozen_string_literal: true

require 'fileutils'
require 'google/protobuf'
require 'open3'

# Generator for the proto files.
class ProtoGen
  MINIMUM_PROTOC_VERSION = Gem::Version.new('34.0')
  SERVICE_DEFINITIONS = [
    {
      require_path: './lib/temporalio/api/workflowservice/v1/service',
      qualified_service_name: 'temporal.api.workflowservice.v1.WorkflowService',
      file_name: 'workflow_service',
      class_name: 'WorkflowService',
      service_enum: 'SERVICE_WORKFLOW',
      trait: 'WorkflowService',
      service_method: 'workflow_service'
    },
    {
      require_path: './lib/temporalio/api/operatorservice/v1/service',
      qualified_service_name: 'temporal.api.operatorservice.v1.OperatorService',
      file_name: 'operator_service',
      class_name: 'OperatorService',
      service_enum: 'SERVICE_OPERATOR',
      trait: 'OperatorService',
      service_method: 'operator_service'
    },
    {
      require_path: './lib/temporalio/api/cloud/cloudservice/v1/service',
      qualified_service_name: 'temporal.api.cloud.cloudservice.v1.CloudService',
      file_name: 'cloud_service',
      class_name: 'CloudService',
      service_enum: 'SERVICE_CLOUD',
      trait: 'CloudService',
      service_method: 'cloud_service'
    },
    {
      require_path: './lib/temporalio/api/testservice/v1/service',
      qualified_service_name: 'temporal.api.testservice.v1.TestService',
      file_name: 'test_service',
      class_name: 'TestService',
      service_enum: 'SERVICE_TEST',
      trait: 'TestService',
      service_method: 'test_service'
    }
  ].freeze
  GENERATED_PATHS = [
    'lib/temporalio/api',
    'lib/temporalio/internal/bridge/api',
    'sig/temporalio/api',
    'sig/temporalio/internal/bridge/api',
    *SERVICE_DEFINITIONS.flat_map do |service|
      [
        "lib/temporalio/client/connection/#{service[:file_name]}.rb",
        "sig/temporalio/client/connection/#{service[:file_name]}.rbs"
      ]
    end,
    'ext/src/client_rpc_generated.rs'
  ].freeze

  # All generated paths.
  def self.generated_paths
    GENERATED_PATHS
  end

  # Run the generator
  def run
    FileUtils.rm_rf('lib/temporalio/api')
    FileUtils.rm_rf('sig/temporalio/api')
    FileUtils.rm_rf('sig/temporalio/internal/bridge/api')

    verify_protoc!

    generate_api_protos(Dir.glob('ext/sdk-core/crates/common/protos/api_upstream/**/*.proto').reject do |proto|
      proto.include?('google')
    end)
    generate_api_protos(Dir.glob('ext/sdk-core/crates/common/protos/api_cloud_upstream/**/*.proto'))
    generate_api_protos(Dir.glob('ext/sdk-core/crates/common/protos/testsrv_upstream/**/*.proto'))
    generate_api_protos(Dir.glob('ext/additional_protos/**/*.proto'))
    generate_import_helper_files
    generate_service_files
    generate_rust_client_file
    generate_core_protos
    generate_payload_visitor
  end

  private

  def generate_api_protos(api_protos)
    # Generate API to temp dir and move
    FileUtils.rm_rf('tmp-proto')
    FileUtils.mkdir_p(['tmp-proto/ruby', 'tmp-proto/rbs'])
    system(
      protoc_command,
      *google_proto_include_flags,
      '--proto_path=ext/sdk-core/crates/common/protos/api_upstream',
      '--proto_path=ext/sdk-core/crates/common/protos/api_cloud_upstream',
      '--proto_path=ext/sdk-core/crates/common/protos/testsrv_upstream',
      '--proto_path=ext/additional_protos',
      '--ruby_out=tmp-proto/ruby',
      '--rbs_out=tmp-proto/rbs',
      *api_protos,
      exception: true
    )

    # Walk all generated Ruby files and cleanup content and filename
    Dir.glob('tmp-proto/ruby/temporal/api/**/*.rb') do |path|
      # Fix up the import
      content = File.read(path)
      content.gsub!(%r{^require 'temporal/(.*)_pb'$}, "require 'temporalio/\\1'")
      File.write(path, content)

      # Remove _pb from the filename
      FileUtils.mv(path, path.sub('_pb', ''))
    end

    # Move from temp dir and remove temp dir
    Dir.glob('tmp-proto/rbs/temporal/api/**/*.rbs') { |path| normalize_generated_rbs!(path) }
    FileUtils.cp_r('tmp-proto/ruby/temporal/api', 'lib/temporalio')
    FileUtils.mkdir_p('sig/temporalio')
    FileUtils.cp_r('tmp-proto/rbs/temporal/api', 'sig/temporalio')
    FileUtils.rm_rf('tmp-proto')
  end

  def generate_import_helper_files
    # Write files that will help with imports. We are requiring the
    # request_response and not the service because the service depends on Google
    # API annotations we don't want to have to depend on.
    File.write(
      'lib/temporalio/api/cloud/cloudservice.rb',
      <<~TEXT
        # frozen_string_literal: true

        require 'temporalio/api/cloud/cloudservice/v1/request_response'
      TEXT
    )
    File.write(
      'lib/temporalio/api/workflowservice.rb',
      <<~TEXT
        # frozen_string_literal: true

        require 'temporalio/api/workflowservice/v1/request_response'
      TEXT
    )
    File.write(
      'lib/temporalio/api/operatorservice.rb',
      <<~TEXT
        # frozen_string_literal: true

        require 'temporalio/api/operatorservice/v1/request_response'
      TEXT
    )
    File.write(
      'lib/temporalio/api.rb',
      <<~TEXT
        # frozen_string_literal: true

        require 'temporalio/api/cloud/cloudservice'
        require 'temporalio/api/common/v1/grpc_status'
        require 'temporalio/api/errordetails/v1/message'
        require 'temporalio/api/export/v1/message'
        require 'temporalio/api/operatorservice'
        require 'temporalio/api/sdk/v1/workflow_metadata'
        require 'temporalio/api/workflowservice'

        module Temporalio
          # Raw protocol buffer models.
          module Api
          end
        end
      TEXT
    )
  end

  def generate_service_files
    SERVICE_DEFINITIONS.each do |service|
      require service[:require_path]
      generate_service_file(
        qualified_service_name: service[:qualified_service_name],
        file_name: service[:file_name],
        class_name: service[:class_name],
        service_enum: service[:service_enum]
      )
    end
  end

  def generate_service_file(qualified_service_name:, file_name:, class_name:, service_enum:)
    # Do service lookup
    desc = Google::Protobuf::DescriptorPool.generated_pool.lookup(qualified_service_name)
    raise 'Failed finding service descriptor' unless desc

    # Open file to generate Ruby code
    File.open("lib/temporalio/client/connection/#{file_name}.rb", 'w') do |file|
      file.puts <<~TEXT
        # frozen_string_literal: true

        # Generated code.  DO NOT EDIT!

        require 'temporalio/api'
        require 'temporalio/client/connection/service'
        require 'temporalio/internal/bridge/client'

        module Temporalio
          class Client
            class Connection
              # #{class_name} API.
              class #{class_name} < Service
                # @!visibility private
                def initialize(connection)
                  super(connection, Internal::Bridge::Client::#{service_enum})
                end
      TEXT

      desc.each do |method|
        # Camel case to snake case
        rpc = method.name.gsub(/([A-Z])/, '_\1').downcase.delete_prefix('_')
        file.puts <<-TEXT

        # Calls #{class_name}.#{method.name} API call.
        #
        # @param request [#{method.input_type.msgclass}] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [#{method.output_type.msgclass}] API response.
        def #{rpc}(request, rpc_options: nil)
          invoke_rpc(
            rpc: '#{rpc}',
            request_class: #{method.input_type.msgclass},
            response_class: #{method.output_type.msgclass},
            request:,
            rpc_options:
          )
        end
        TEXT
      end

      file.puts <<~TEXT
              end
            end
          end
        end
      TEXT
    end

    # Open file to generate RBS code
    File.open("sig/temporalio/client/connection/#{file_name}.rbs", 'w') do |file|
      file.puts <<~TEXT
        # Generated code.  DO NOT EDIT!

        module Temporalio
          class Client
            class Connection
              class #{class_name} < Service
                def initialize: (Connection) -> void
      TEXT

      desc.each do |method|
        # Camel case to snake case
        rpc = method.name.gsub(/([A-Z])/, '_\1').downcase.delete_prefix('_')
        file.puts <<-TEXT
        def #{rpc}: (
          #{method.input_type.msgclass} request,
          ?rpc_options: RPCOptions?
        ) -> #{method.output_type.msgclass}
        TEXT
      end

      file.puts <<~TEXT
              end
            end
          end
        end
      TEXT
    end
  end

  def generate_rust_client_file
    File.open('ext/src/client_rpc_generated.rs', 'w') do |file|
      file.puts <<~TEXT
        // Generated code.  DO NOT EDIT!

        use magnus::{Error, Ruby};
        use temporalio_client::grpc::{CloudService, OperatorService, TestService, WorkflowService};

        use super::{error, rpc_call};
        use crate::{
            client::{Client, RpcCall, SERVICE_CLOUD, SERVICE_OPERATOR, SERVICE_TEST, SERVICE_WORKFLOW},
            util::AsyncCallback,
        };

        impl Client {
            pub fn invoke_rpc(&self, service: u8, callback: AsyncCallback, call: RpcCall) -> Result<(), Error> {
                match service {
      TEXT
      SERVICE_DEFINITIONS.each do |service|
        generate_rust_match_arm(
          file:,
          qualified_service_name: service[:qualified_service_name],
          service_enum: service[:service_enum],
          trait: service[:trait],
          service_method: service[:service_method]
        )
      end
      file.puts <<~TEXT
                    _ => Err(error!("Unknown service")),
                }
            }
        }
      TEXT
    end
    system('cargo', 'fmt', '--', 'ext/src/client_rpc_generated.rs', exception: true)
  end

  def generate_rust_match_arm(file:, qualified_service_name:, service_enum:, trait:, service_method:)
    # Do service lookup
    desc = Google::Protobuf::DescriptorPool.generated_pool.lookup(qualified_service_name)
    file.puts <<~TEXT
      #{service_enum} => match call.rpc.as_str() {
    TEXT

    desc.to_a.sort_by(&:name).each do |method|
      # Camel case to snake case
      rpc = method.name.gsub(/([A-Z])/, '_\1').downcase.delete_prefix('_')
      file.puts <<~TEXT
        "#{rpc}" => rpc_call!(self, callback, call, #{trait}, #{service_method}, #{rpc}),
      TEXT
    end
    file.puts <<~TEXT
        _ => Err(error!("Unknown RPC call {}", call.rpc)),
      },
    TEXT
  end

  def generate_core_protos
    FileUtils.rm_rf('lib/temporalio/internal/bridge/api')
    # Generate API to temp dir
    FileUtils.rm_rf('tmp-proto')
    FileUtils.mkdir_p(['tmp-proto/ruby', 'tmp-proto/rbs'])
    system(
      protoc_command,
      *google_proto_include_flags,
      '--proto_path=ext/sdk-core/crates/common/protos/api_upstream',
      '--proto_path=ext/sdk-core/crates/common/protos/local',
      '--ruby_out=tmp-proto/ruby',
      '--rbs_out=tmp-proto/rbs',
      *Dir.glob('ext/sdk-core/crates/common/protos/local/**/*.proto'),
      exception: true
    )
    # Walk all generated Ruby files and cleanup content and filename
    Dir.glob('tmp-proto/ruby/temporal/sdk/**/*.rb') do |path|
      # Fix up the imports
      content = File.read(path)
      content.gsub!(%r{^require 'temporal/(.*)_pb'$}, "require 'temporalio/\\1'")
      content.gsub!(%r{^require 'temporalio/sdk/core/(.*)'$}, "require 'temporalio/internal/bridge/api/\\1'")
      File.write(path, content)

      # Remove _pb from the filename
      FileUtils.mv(path, path.sub('_pb', ''))
    end
    # Move from temp dir and remove temp dir
    Dir.glob('tmp-proto/rbs/temporal/sdk/**/*.rbs') { |path| normalize_generated_rbs!(path) }
    FileUtils.mkdir_p('lib/temporalio/internal/bridge/api')
    FileUtils.cp_r(Dir.glob('tmp-proto/ruby/temporal/sdk/core/*'), 'lib/temporalio/internal/bridge/api')
    FileUtils.mkdir_p('sig/temporalio/internal/bridge/api')
    FileUtils.cp_r(Dir.glob('tmp-proto/rbs/temporal/sdk/core/*'), 'sig/temporalio/internal/bridge/api')
    FileUtils.rm_rf('tmp-proto')
  end

  def generate_payload_visitor
    require_relative 'payload_visitor_gen'
    gen = PayloadVisitorGen.new
    File.write('lib/temporalio/api/payload_visitor.rb', gen.gen_file_code)
    FileUtils.mkdir_p('sig/temporalio/api')
    File.write('sig/temporalio/api/payload_visitor.rbs', gen.gen_rbs_code)
  end

  def protoc_command
    ENV.fetch('PROTOC', 'protoc')
  end

  def google_proto_include_flags
    include_dir = ENV.fetch('PROTOC_INCLUDE', nil)
    include_dir ? ["--proto_path=#{include_dir}"] : []
  end

  def protoc_version
    @protoc_version ||= begin
      version_output, status = Open3.capture2(protoc_command, '--version')
      raise "Failed running #{protoc_command.inspect} --version" unless status.success?

      version_output.split.last
    end
  end

  def verify_protoc!
    version = Gem::Version.new(protoc_version)
    return if version >= MINIMUM_PROTOC_VERSION

    raise "protoc #{MINIMUM_PROTOC_VERSION} or newer is required, got #{version}"
  rescue Errno::ENOENT
    raise "protoc #{MINIMUM_PROTOC_VERSION} or newer is required and was not found"
  end

  # Protobuf generates overly specific type signatures that result in Steep choking while creating union types.
  # To avoid this, we widen them to their supertype e.g. `lookup` taking a String compared to the union type of each
  # message type string literal.
  def normalize_generated_rbs!(path)
    content = File.read(path)
    # These mixins are currently not part of the google-protobuf RBS files, so we strip them to avoid type errors.
    content.gsub!(/^\s*include ::Google::Protobuf::_MessageClass\[[^\]]+\]\n/, '')
    content.gsub!(/^\s*extend ::Google::Protobuf::_EnumModule\n/, '')
    content.gsub!(
      /\(::Google::Protobuf::Descriptor & ::Google::Protobuf::_SpecificDescriptor\[[^\]]+\]\)/,
      '::Google::Protobuf::Descriptor'
    )
    content.gsub!(
      /\(::Google::Protobuf::EnumDescriptor & ::Google::Protobuf::_SpecificEnumDescriptor\[[^\]]+\]\)/,
      '::Google::Protobuf::EnumDescriptor'
    )
    content.gsub!(/::Google::Protobuf::RepeatedField\[[^\]]+\]/, '::Google::Protobuf::RepeatedField')
    content.gsub!(
      /::Google::Protobuf::Map\[([^,\]]+), ([^,\]]+), [^\]]+\]/,
      '::Google::Protobuf::Map[\1, \2]'
    )
    # The plugin emits constructor helpers as `Type::init_map`; the runtime API exposed to callers is just `Type`.
    content.gsub!(/::Google::Protobuf::([A-Za-z]+)::init_map/, '::Google::Protobuf::\1')
    content.gsub!(
      /^(\s*)def self\.lookup:\n.*?^(?=\1def self\.resolve:)/m,
      "\\1def self.lookup: (::Integer number) -> ::Symbol\n\n"
    )
    content.gsub!(
      /^(\s*)def self\.resolve:\n.*?^(?=\1type names =)/m,
      "\\1def self.resolve: (::Symbol name) -> ::Integer\n\n"
    )
    content.gsub!(
      /^(\s*)class DescriptorPool\n\1  def lookup:\n.*?^(?=\1end$)/m,
      "\\1class DescriptorPool\n\\1  def lookup: (::String name) -> ::Google::Protobuf::Descriptor\n"
    )
    File.write(path, content)
    # Keep RBS filenames aligned with the Ruby files we already rename away from the `_pb` suffix.
    FileUtils.mv(path, path.sub('_pb', ''))
  end
end
