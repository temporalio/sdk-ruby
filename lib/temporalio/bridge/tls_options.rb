module Temporalio
  module Bridge
    class TlsOptions < Struct.new(
      :server_root_ca_cert,
      :client_cert,
      :client_private_key,
      :server_name_override,
      keyword_init: true,
    ); end
  end
end
