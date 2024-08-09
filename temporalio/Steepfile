# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature 'sig', 'test/sig'

  check 'lib', 'test'

  ignore 'lib/temporalio/api'

  library 'uri'

  configure_code_diagnostics do |hash|
    hash[D::Ruby::UnknownConstant] = :information
    hash[D::Ruby::NoMethod] = :information
  end
end
