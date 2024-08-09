# frozen_string_literal: true

require 'temporalio/internal/bridge'
require 'temporalio/temporalio_bridge'

module Temporalio
  module Internal
    module Bridge
      module Testing
        # @!visibility private
        class EphemeralServer
          # @!visibility private
          StartDevServerOptions = Struct.new(
            :existing_path, # Optional
            :sdk_name,
            :sdk_version,
            :download_version,
            :download_dest_dir, # Optional
            :namespace,
            :ip,
            :port, # Optional
            :database_filename, # Optional
            :ui,
            :log_format,
            :log_level,
            :extra_args,
            keyword_init: true
          )

          # @!visibility private
          def self.start_dev_server(runtime, options)
            Bridge.async_call do |queue|
              async_start_dev_server(runtime, options) do |val|
                queue.push(val)
              end
            end
          end

          # @!visibility private
          def shutdown
            Bridge.async_call do |queue|
              async_shutdown do |val|
                queue.push(val)
              end
            end
          end
        end
      end
    end
  end
end
