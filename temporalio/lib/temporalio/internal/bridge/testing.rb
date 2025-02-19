# frozen_string_literal: true

require 'temporalio/internal/bridge'

module Temporalio
  module Internal
    module Bridge
      module Testing
        class EphemeralServer
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
            :ui_port, # Optional, should be nil if ui is false
            :log_format,
            :log_level,
            :extra_args,
            keyword_init: true
          )

          StartTestServerOptions = Struct.new(
            :existing_path, # Optional
            :sdk_name,
            :sdk_version,
            :download_version,
            :download_dest_dir, # Optional
            :port, # Optional
            :extra_args,
            keyword_init: true
          )

          def self.start_dev_server(runtime, options)
            queue = Queue.new
            async_start_dev_server(runtime, options, queue)
            result = queue.pop
            raise result if result.is_a?(Exception)

            result
          end

          def self.start_test_server(runtime, options)
            queue = Queue.new
            async_start_test_server(runtime, options, queue)
            result = queue.pop
            raise result if result.is_a?(Exception)

            result
          end

          def shutdown
            queue = Queue.new
            async_shutdown(queue)
            result = queue.pop
            raise result if result.is_a?(Exception)
          end
        end
      end
    end
  end
end
