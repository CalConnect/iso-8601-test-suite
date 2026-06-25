# frozen_string_literal: true

require 'set'

module SuiteValidations
  URN_PATTERN = /\Aurn:iso:std:iso:8601:-[12]:ed-1:en(:clause:[0-9A-Za-z.,]+)?\z/
  URL_PATTERN = /\Ahttps?:\/\/.+\z/
  FORMAT_KEYWORDS = /\b(basic format|extended format|representation|shall be represented|in the form|format|pattern)\b/i
  TEST_ID_PATTERN = /\Aconf-test:[a-z][a-z0-9]*(-[a-z0-9]+)*-\d{3}\z/

  module_function

  def check_urn_format(source_map, stats)
    checked = 0
    bad = 0
    source_map.each do |f, sources|
      next unless f.start_with?("requirements/", "tests/", "profiles/")
      Array(sources).each do |s|
        checked += 1
        unless s.match?(URN_PATTERN) || s.match?(URL_PATTERN)
          stats.error(f, "source '#{s}' does not match RFC 5141 URN or URL format")
          bad += 1
        end
      end
    end
    [checked, bad]
  end

  def check_source_consistency(index, store, stats)
    mismatches = 0
    index.bare_conf_class_ids.each do |cc_id|
      cc_file = index.conf_class_ids[cc_id]
      cc_source = index.source_map[cc_file]

      cc_result = store.load(cc_file)
      next if cc_result.failure?
      rc_ref = cc_result.data["requirements_class"]
      next unless rc_ref

      rc_file = index.req_class_ids[rc_ref]
      next unless rc_file

      rc_source = index.source_map[rc_file]
      next if rc_source.nil? || cc_source.nil?

      rc_set = Array(rc_source).to_set
      cc_set = Array(cc_source).to_set

      unless rc_set == cc_set
        only_rc = rc_set - cc_set
        only_cc = cc_set - rc_set
        details = []
        details << "only in req-class: #{only_rc.to_a.join(', ')}" unless only_rc.empty?
        details << "only in conf-class: #{only_cc.to_a.join(', ')}" unless only_cc.empty?
        stats.warn(cc_file, "source mismatch with #{rc_file}: #{details.join('; ')}")
        mismatches += 1
      end
    end
    [index.bare_conf_class_ids.length, mismatches]
  end

  def check_pattern_coverage(store, stats)
    total_format = 0
    missing = 0
    store.files_in("requirements/**/*.yaml").each do |f|
      result = store.load(f)
      next if result.failure?
      data = result.data
      (data["requirements"] || []).each do |r|
        stmt = r["statement"]
        next unless stmt
        next if r["format"] == "any"
        if stmt.match?(FORMAT_KEYWORDS)
          total_format += 1
          unless r.key?("pattern")
            stats.warn(f, "#{r['id']}: statement references format but has no 'pattern' field")
            missing += 1
          end
        end
      end
    end
    [total_format, missing]
  end

  def check_test_id_naming(test_ids, stats)
    checked = 0
    bad = 0
    test_ids.each do |tid, f|
      checked += 1
      unless tid.match?(TEST_ID_PATTERN)
        stats.warn(f, "test ID '#{tid}' does not follow naming convention conf-test:{prefix}-{type}-{NNN}")
        bad += 1
      end
    end
    [checked, bad]
  end

  def check_test_req_references(index, stats)
    known = index.all_req_ids.to_set
    checked = 0
    bad = 0
    index.test_reqs.each do |tid, reqs|
      file = index.file_for_test(tid) || "tests"
      Array(reqs).each do |r|
        checked += 1
        unless known.include?(r)
          stats.error(file, "#{tid}: references undefined requirement '#{r}'")
          bad += 1
        end
      end
    end
    [checked, bad]
  end

  def check_component_keys(vocab, stats, file, test_id, components)
    return unless components.is_a?(Hash)

    components.each_key do |key|
      stats.warn(file, "#{test_id}: unknown component key '#{key}'") unless vocab.known_top_key?(key)
    end

    components.each do |parent, sub|
      next unless sub.is_a?(Hash)
      sub.each_key do |key|
        stats.warn(file, "#{test_id}: unknown #{parent} component key '#{key}'") unless vocab.known_sub_key?(parent, key)
      end
    end
  end
end
