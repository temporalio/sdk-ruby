# frozen_string_literal: true

require 'rake'

Rake.application.init
Rake.application.load_rakefile

# rake-compiler may omit this task when the builder reports linux-gnu but normalizes the gem platform to linux.
# Its cross task requires the task to exist before it can replace the native compilation prerequisites.
Rake::Task.define_task(:native)
Rake::Task[:cross].invoke
Rake::Task["native:#{ENV.fetch('RUBY_TARGET')}"].invoke
Rake::Task[:gem].invoke
