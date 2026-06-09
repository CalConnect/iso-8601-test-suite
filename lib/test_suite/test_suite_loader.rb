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
    result.data["tests"] || []
  end

  def tests_for_profile(profile_id)
    profile = @index.profiles[profile_id]
    return [] unless profile

    tests = []

    if profile["traceability"] && !profile["traceability"].empty?
      profile["traceability"].each do |tc|
        cc_ref = tc["conformance_class"]
        cc_tests = tests_for_class(cc_ref)
        explicit_reqs = tc["requirements"]
        if explicit_reqs && !explicit_reqs.empty?
          cc_tests = cc_tests.select { |t|
            (t["requirements"] || []).any? { |r| explicit_reqs.include?(r) }
          }
        end
        tests.concat(cc_tests)
      end
    elsif profile["conformance_classes"]
      (profile["conformance_classes"] || []).each do |cc_ref|
        tests.concat(tests_for_class(cc_ref))
      end
    end

    (profile["additional_tests"] || []).each { |t| tests << t }
    tests
  end

  def all_tests
    @index.conf_test_ids.map { |tid, f|
      result = @store.load(f)
      next if result.failure?
      data = result.data
      test_list = data["tests"] || data["additional_tests"] || []
      test_list.find { |t| t["id"] == tid }
    }.compact
  end

  def profile_ids
    @index.profile_ids.sort
  end

  def class_ids
    @index.bare_conf_class_ids.sort
  end
end
