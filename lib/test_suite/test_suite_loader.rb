# frozen_string_literal: true

class TestSuiteLoader
  def initialize(store, index)
    @store = store
    @index = index
    @index.load_all
  end

  def tests_for_class(class_id)
    resolved = @index.resolve_class(class_id)
    return [] unless resolved

    file, _bare = resolved
    result = @store.load(file)
    return [] if result.failure?
    (result.data["tests"] || []).map { |t| Test.new(t) }
  end

  def tests_for_profile(profile_id)
    profile = @index.profiles[profile_id]
    return [] unless profile

    tests = []

    @index.profile_traceability(profile_id).each do |tc|
      cc_tests = tests_for_class(tc[:conformance_class])
      if tc[:requirements] && !tc[:requirements].empty?
        cc_tests = cc_tests.select { |t|
          t.requirements.any? { |r| tc[:requirements].include?(r) }
        }
      end
      tests.concat(cc_tests)
    end

    (profile["additional_tests"] || []).each { |t| tests << Test.new(t) }
    tests
  end

  def all_tests
    @index.conf_test_ids.map { |tid, f|
      result = @store.load(f)
      next if result.failure?
      data = result.data
      test_list = data["tests"] || data["additional_tests"] || []
      raw = test_list.find { |t| t["id"] == tid }
      raw && Test.new(raw)
    }.compact
  end

  def profile_ids
    @index.profile_ids.sort
  end

  def class_ids
    @index.conf_class_ids.keys.sort
  end
end
