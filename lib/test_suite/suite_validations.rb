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

  def check_unreferenced_requirements(index, stats)
    referenced = index.test_reqs.values.flatten.to_set
    all_reqs = index.all_req_ids
    unreferenced = all_reqs - referenced.to_a
    unreferenced.each do |r|
      source = index.req_ids[r] || index.profile_req_ids[r]
      stats.warn(source, "#{r}: not referenced by any test")
    end
    [all_reqs.length, unreferenced.length]
  end

  def check_profile_references(index, store, stats)
    checked = 0
    errors = 0
    store.files_in("profiles/**/*.yaml").each do |f|
      next if File.basename(f) == "TEMPLATE.yaml"
      result = store.load(f)
      next if result.failure?

      data = result.data
      before = stats.error_count_snapshot

      (data["conformance_classes"] || []).each do |cc|
        unless index.conf_class_ids.key?(cc)
          stats.error(f, "references unknown conformance class '#{cc}'")
        end
      end

      (data["additional_tests"] || []).each do |t|
        tid = t["id"]
        (t["requirements"] || []).each do |r|
          unless index.req_ids.key?(r) || index.profile_req_ids.key?(r)
            stats.error(f, "test #{tid}: references undefined requirement '#{r}' (not in requirements/ or profile additional_requirements)")
          end
        end
        if index.conf_test_ids.key?(tid) && index.conf_test_ids[tid] != f
          prev = index.conf_test_ids[tid]
          stats.error(f, "duplicate test ID '#{tid}' (also in #{prev})")
        end
      end

      checked += 1
      errors += stats.error_count_snapshot - before
    end
    [checked, errors]
  end

  def check_result_references(index, store, stats)
    checked = 0
    errors = 0
    store.files_in("results/**/*.yaml")
      .reject { |f| File.basename(f) == "TEMPLATE.yaml" }
      .each do |f|
        result = store.load(f)
        next if result.failure?

        data = result.data
        before = stats.error_count_snapshot

        (data["conformance_class_results"] || []).each do |cc|
          cc_ref = cc["conformance_class"]
          unless index.conf_class_ids.key?(cc_ref)
            stats.error(f, "references unknown conformance class '#{cc_ref}'")
          end
          (cc["test_results"] || []).each do |tr|
            unless index.conf_test_ids.key?(tr["test"])
              stats.error(f, "references undefined test '#{tr['test']}'")
            end
          end
        end

        (data["profile_results"] || []).each do |pr|
          (pr["test_results"] || []).each do |tr|
            unless index.conf_test_ids.key?(tr["test"])
              stats.error(f, "references undefined profile test '#{tr['test']}'")
            end
          end
        end

        checked += 1
        errors += stats.error_count_snapshot - before
      end
    [checked, errors]
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
