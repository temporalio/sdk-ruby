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

    # Due to the lack of cross-compilation support, thermite assumes the resulting binary
    # is placed in target/<profile>, however it's actually in target/<target_arch>/<profile>
    def cargo_target_path(profile, *path_components)
      target_base = ENV.fetch('CARGO_TARGET_DIR', File.join(rust_toplevel_dir, 'target'))
      File.join(target_base, ENV.fetch('CARGO_BUILD_TARGET', ''), profile, *path_components)
    end

    def dynamic_linker_flags
      @dynamic_linker_flags ||= begin
        default_flags = RbConfig::CONFIG['DLDFLAGS'].strip
        if target_os == 'darwin' && !default_flags.include?('-Wl,-undefined,dynamic_lookup')
          default_flags += ' -Wl,-undefined,dynamic_lookup'
        end
        default_flags
      end
    end
  end
end
