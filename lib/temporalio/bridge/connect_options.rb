module Temporalio
  module Bridge
    class ConnectOptions < Struct.new(
      :url,
      :tls,
      :client_version,
      :metadata,
      :retry_config,
      keyword_init: true,
    ); end
  end
end
