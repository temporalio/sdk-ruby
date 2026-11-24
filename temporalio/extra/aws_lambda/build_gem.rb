# frozen_string_literal: true

require 'rake'

Rake.application.init
Rake.application.load_rakefile

# rake-compiler can normalize linux-gnu to linux and omit the native task. Cross mode replaces the gem's
# compilation prerequisites so packaging does not try to link an ARM extension with the host's x86 compiler.
Rake::Task.define_task(:native)
Rake::Task[:cross].invoke
Rake::Task["native:#{ENV.fetch('RUBY_TARGET')}"].invoke
Rake::Task[:gem].invoke
