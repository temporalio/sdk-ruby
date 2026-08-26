# frozen_string_literal: true

require 'test'

class CloudTestInventoryTest < Test
  def test_report
    return unless TemporalioTestMode.cloud_inventory?

    exclusions = Test::CLOUD_TEST_EXCLUSION_REASONS.to_h { |reason, _| [reason, []] }
    test_classes = Minitest::Runnable.runnables.select do |runnable|
      runnable.is_a?(Class) && runnable < Test
    end
    test_classes.uniq.sort_by { |test_class| test_class.name.to_s }.each do |test_class|
      test_class.runnable_methods.sort.each do |method_name|
        # Fiber variants are generated copies with the same exclusion, so report the source annotation once.
        next if method_name.end_with?('_in_fiber')

        exclusion = test_class.cloud_test_exclusion(method_name)
        next unless exclusion

        exclusions.fetch(exclusion.reason) << ["#{test_class}##{method_name}", exclusion.note]
      end
    end

    puts 'Cloud test exclusions'
    Test::CLOUD_TEST_EXCLUSION_REASONS.each do |reason, description|
      tests = exclusions.fetch(reason).sort_by(&:first)
      puts
      puts "#{reason} (#{tests.length}) — #{description}"
      tests.each { |name, note| puts "  #{name} — #{note}" }
    end
  end
end
