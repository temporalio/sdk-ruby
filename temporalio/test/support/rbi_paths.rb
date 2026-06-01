# frozen_string_literal: true

module RbiPaths
  ROOT = File.expand_path('../../rbi', __dir__)

  GENERATED_PREFIXES = [
    File.join(ROOT, 'google', ''),
    File.join(ROOT, 'temporalio', 'api', ''),
    File.join(ROOT, 'temporalio', 'client', 'connection', '')
  ].freeze

  class << self
    def all
      Dir.glob(File.join(ROOT, '**', '*.rbi'))
    end

    def manual
      paths = [
        File.join(ROOT, 'temporalio.rbi'),
        *Dir.glob(File.join(ROOT, 'temporalio', '**', '*.rbi'))
      ]
      paths
        .uniq
        .select { |path| File.file?(path) }
        .reject { |path| GENERATED_PREFIXES.any? { |prefix| path.start_with?(prefix) } }
        .sort
    end
  end
end
