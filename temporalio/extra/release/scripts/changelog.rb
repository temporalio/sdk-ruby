# frozen_string_literal: true

require 'pathname'

# Language release adapters delegate changelog operations to the pinned Core tool.
module Changelog
  REPO_ROOT = Pathname.new(__dir__).parent.parent.parent.parent.expand_path
  CORE_PATH = 'temporalio/ext/sdk-core'

  # Run a shared changelog command against the SDK repository.
  def self.run(*args, repo_root: REPO_ROOT)
    core = repo_root.join(CORE_PATH)
    system(
      'cargo', 'run', '--manifest-path', core.join('crates/changelog-release-notes/Cargo.toml').to_s,
      '--bin', 'changelog-tool', '--', *args, '--repo', repo_root.to_s,
      chdir: repo_root.to_s, exception: true
    )
  end
end

Changelog.run(*ARGV) if $PROGRAM_NAME == __FILE__
