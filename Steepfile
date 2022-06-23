# D = Steep::Diagnostic

target :lib do
  signature 'sig'

  check 'lib'

  repo_path 'vendor/rbs/gem_rbs_collection/gems'
  library 'protobuf'

  ignore 'lib/gen/*.rb'

  # library 'pathname', 'set'       # Standard libraries

  # configure_code_diagnostics(D::Ruby.strict)       # `strict` diagnostics setting
  # configure_code_diagnostics(D::Ruby.lenient)      # `lenient` diagnostics setting
  # configure_code_diagnostics do |hash|             # You can setup everything yourself
  #   hash[D::Ruby::NoMethod] = :information
  # end
end
