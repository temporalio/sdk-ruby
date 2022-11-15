require 'rbconfig'

module Thermite
  class Config
    # Thermite doesn't support cross-compilation so it always assumes the binary is being
    # built for the current architecture. It only really affects the name of the tarball.
    def target_arch
      @target_arch ||= ENV.fetch('TARGET_ARCH', RbConfig::CONFIG['target_cpu'])
    end

    # Use the same target for all darwin versions
    def target_os
      @target_os ||= RbConfig::CONFIG['target_os'].sub(/darwin\d+/, 'darwin')
    end
  end
end
