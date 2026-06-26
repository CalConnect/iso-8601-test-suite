# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'set'
require 'yaml'

class CapabilityMatrix
  CONFIG_PATH = File.expand_path(File.join(__dir__, "..", "..", "config", "adapters.yaml"))
  REPO_ROOT   = File.expand_path(File.join(__dir__, "..", ".."))

  # Load adapter definitions from a YAML config file.
  #
  # The config has two sections:
  #   paths:    name → filesystem path (may use ~ for home)
  #   adapters: list of {id, name, family, logo, adapter}
  #
  # The `adapter` field may reference path entries via ${name} interpolation,
  # plus the built-in ${repo_root} for repo-relative references.
  def self.load_adapter_defs(config_path)
    raw = YAML.load_file(config_path)
    paths = (raw["paths"] || {}).each_with_object({}) do |(k, v), h|
      h[k.to_s] = v.to_s
    end
    paths["repo_root"] = REPO_ROOT

    (raw["adapters"] || []).map do |entry|
      {
        id:      entry.fetch("id"),
        name:    entry.fetch("name"),
        family:  entry.fetch("family"),
        logo:    entry.fetch("logo"),
        adapter: interpolate_paths(entry.fetch("adapter"), paths),
      }
    end
  end

  def self.interpolate_paths(template, vars)
    template.gsub(/\$\{([a-z0-9_]+)\}/i) do
      key = Regexp.last_match(1)
      vars.key?(key) ? vars[key] : "${#{key}}"
    end
  end
  private_class_method :interpolate_paths

  # Adapter registry, loaded from config/adapters.yaml and frozen.
  ADAPTER_DEFS = load_adapter_defs(CONFIG_PATH).freeze

  TEST_TYPE_TO_CAPABILITY = {
    "validity"    => "parse_general",
    "parsing"     => "parse_general",
    "generation"  => "construct",
    "equivalence" => "parse_general",
    "arithmetic"  => "arithmetic",
    "round_trip"  => "parse_general",
  }.freeze

  PROFILE_ORG_LOGOS = {
    "profile:rfc-3339"                => "/logos/ietf.svg",
    "profile:w3c-datetime"            => "/logos/w3c.svg",
    "profile:edtf-level-0"            => "/logos/loc.svg",
    "profile:edtf-level-1"            => "/logos/loc.svg",
    "profile:edtf-level-2"            => "/logos/loc.svg",
    "profile:iso-8601-1-complete"     => "/logos/iso-red.svg",
    "profile:iso-8601-1-core"         => "/logos/iso-red.svg",
    "profile:iso-8601-2-complete"     => "/logos/iso-red.svg",
    "profile:iso-8601-1-basic-format" => "/logos/iso-red.svg",
  }.freeze

  def initialize(store, index, suite)
    @store = store
    @index = index
    @suite = suite
  end

  def generate(adapter_defs: ADAPTER_DEFS, on_progress: nil)
    req_index = build_requirements_index
    adapters = load_adapters(adapter_defs, on_progress)
    declared_classes = adapters.to_h { |a| [a[:id], read_declared_classes(a[:id])] }
    declared_profiles = adapters.to_h { |a| [a[:id], read_declared_profiles(a[:id])] }
    all_tests = @suite.all_tests
    test_reqs = @index.test_reqs

    req_tests = build_req_tests(all_tests, test_reqs)
    class_tests = build_class_tests(all_tests)
    profile_tests = build_profile_tests(test_reqs)
    profile_req_map = build_profile_req_map(class_tests, test_reqs)

    requirements_output = build_requirements(
      adapters, req_index, req_tests, profile_req_map, declared_classes, on_progress
    )

    profile_results = build_profile_results(
      adapters, profile_tests, test_reqs, req_index, declared_classes
    )

    {
      generated_at: Time.now.utc.iso8601,
      libraries: build_library_output(adapters, profile_results, declared_classes, declared_profiles),
      family_stats: build_family_stats(adapters, requirements_output),
      requirements: requirements_output,
      profiles: profile_results,
      categories: build_categories(requirements_output),
    }
  end

  private

  def load_adapters(adapter_defs, on_progress)
    loaded = []
    adapter_defs.each do |defn|
      begin
        adapter = AdapterLoader.load(defn[:adapter])
        loaded << { **defn, adapter: adapter, version: adapter.version, language: adapter.language }
      rescue AdapterNotFoundError, RuntimeError => e
        on_progress&.call(:adapter_failed, defn[:name], e.message)
      end
    end
    loaded
  end

  def build_requirements_index
    reqs = {}

    @store.files_in("requirements/**/*.yaml").each do |f|
      result = @store.load(f)
      next unless result.success?
      data = result.data
      class_name = data["name"] || data["id"]
      part = @index.part_for_file(f).sub("8601-", "")
      (data["requirements"] || []).each do |r|
        reqs[r["id"]] = Requirement.new(
          r,
          source_class: data["id"],
          category: class_name,
          part: part
        )
      end
    end

    @store.files_in("profiles/**/*.yaml").each do |f|
      next if File.basename(f) == "TEMPLATE.yaml"
      result = @store.load(f)
      next unless result.success?
      profile = Profile.new(result.data)
      profile.additional_requirements.each do |r|
        reqs[r["id"]] = Requirement.new(
          r,
          source_profile: profile.id,
          category: "Profile-Specific (#{profile.name})",
          part: "profile"
        )
      end
    end

    reqs
  end

  def build_req_tests(all_tests, test_reqs)
    req_tests = Hash.new { |h, k| h[k] = [] }
    all_tests.each do |test|
      (test_reqs[test.id] || []).each do |req_id|
        req_tests[req_id] << test
      end
    end
    req_tests
  end

  def build_class_tests(all_tests)
    class_tests = Hash.new { |h, k| h[k] = [] }
    all_tests.each do |test|
      cc_id = @index.class_for_test(test.id)
      class_tests[cc_id] << test if cc_id
    end
    class_tests
  end

  def build_profile_tests(test_reqs)
    profile_tests = {}
    @index.profile_ids.each do |pid|
      tests = @suite.tests_for_profile(pid)
      by_req = Hash.new { |h, k| h[k] = [] }
      tests.each { |t| (test_reqs[t.id] || []).each { |rid| by_req[rid] << t } }
      profile_tests[pid] = by_req
    end
    profile_tests
  end

  def build_profile_req_map(class_tests, test_reqs)
    profile_req_map = {}
    @index.profile_ids.each do |pid|
      profile = @index.profiles[pid]
      next unless profile

      @index.profile_traceability(pid).each do |tc|
        explicit_reqs = tc.requirements
        if explicit_reqs && !explicit_reqs.empty?
          explicit_reqs.each { |rid|
            (profile_req_map[rid] ||= []) << { id: pid, name: profile.name }
          }
        else
          bare = @index.bare_id(tc.conformance_class)
          cc_tests = class_tests[bare] || []
          cc_tests.each { |t| (test_reqs[t.id] || []).each { |rid|
            (profile_req_map[rid] ||= []) << { id: pid, name: profile.name }
          }}
        end
      end

      profile.additional_requirements.each do |ar|
        (profile_req_map[ar["id"]] ||= []) << { id: pid, name: profile.name }
      end
    end
    profile_req_map.transform_values! { |v| v.uniq { |p| p[:id] } }
    profile_req_map
  end

  def build_requirements(adapters, req_index, req_tests, profile_req_map, declared_classes, on_progress)
    all_req_ids = req_index.keys.sort
    (req_tests.keys - all_req_ids).sort.each { |rid| all_req_ids << rid }

    requirements_output = []
    all_req_ids.each do |req_id|
      req = req_index[req_id]
      tests_for_req = req_tests[req_id]
      next if tests_for_req.empty?

      tests_by_type = tests_for_req.group_by { |t| t.test_type }

      req_entry = {
        id: req_id,
        category: req&.category || "Unknown",
        statement: req&.statement,
        format: req&.format,
        clause: req&.clause,
        section: req&.section,
        part: req&.part,
        pattern: req&.pattern,
        source_profile: req&.source_profile,
        profiles: profile_req_map[req_id] || [],
        tests: {},
      }

      adapters.each do |adefn|
        declared = declared_classes[adefn[:id]] || []
        capabilities = build_adapter_capabilities(adefn, tests_by_type, declared)
        req_entry[:tests][adefn[:id]] = capabilities unless capabilities.empty?
      end

      requirements_output << req_entry
      on_progress&.call(:requirement, req_id, req, adapters, req_entry)
    end
    requirements_output
  end

  def build_adapter_capabilities(adefn, tests_by_type, declared)
    adapter = adefn[:adapter]
    declared_bare = declared.map { |d| @index.bare_id(d) }.to_set
    capabilities = {}

    tests_by_type.each do |test_type, tests|
      cap_key = TEST_TYPE_TO_CAPABILITY[test_type] || test_type
      results = run_tests_with_declaration_guard(adapter, tests, declared_bare)
      pass_count = results.count { |r| r["result"] == "pass" }
      not_supported_count = results.count { |r| r["result"] == "not-supported" }
      fail_count = results.count { |r| r["result"] == "fail" || r["result"] == "error" }
      total = results.length

      if total > 0
        status = self.class.classify_status(
          pass: pass_count, fail: fail_count,
          not_supported: not_supported_count, total: total
        )
        capabilities[cap_key] = {
          status: status,
          pass: pass_count,
          total: total,
          details: tests.zip(results).map { |t, r|
            {
              test_id: t.id, description: t.description, test_type: t.test_type,
              given: t.given, expect: t.expect,
              result: r["result"], api: r["api"], notes: r["notes"], actual: r["actual"],
            }
          },
        }
      end
    end
    capabilities
  end

  def build_profile_results(adapters, profile_tests, test_reqs, req_index, declared_classes)
    @index.profile_ids.map do |pid|
      profile = @index.profiles[pid]
      next unless profile

      ptests = profile_tests[pid] || {}

      conf_class_details = build_traceability_details(pid, adapters, test_reqs, req_index, declared_classes)
      req_ids_in_profile = collect_profile_req_ids(profile, conf_class_details)

      adapter_results = adapters.map do |adefn|
        declared = declared_classes[adefn[:id]] || []
        compute_adapter_profile_stats(adefn, req_ids_in_profile, ptests, declared)
      end

      {
        id: pid,
        name: profile.name,
        description: profile.description_stripped,
        source: profile.source,
        logo: PROFILE_ORG_LOGOS[pid],
        traceability_class_count: profile.traceability_count,
        additional_requirements: profile.additional_requirements.map { |r|
          { id: r["id"], statement: r["statement"]&.strip }
        },
        adapter_results: adapter_results,
        traceability: conf_class_details,
      }
    end.compact
  end

  def build_traceability_details(profile_id, adapters, test_reqs, req_index, declared_classes)
    @index.profile_traceability(profile_id).map do |tc|
      cc_id = tc.conformance_class
      explicit_reqs = tc.requirements

      bare = @index.bare_id(cc_id)
      cc_result = @store.load(@index.conf_class_ids[bare]) if @index.conf_class_ids.key?(bare)
      cc_tests = cc_result&.success? ? (cc_result.data["tests"] || []).map { |t| Test.new(t) } : []

      by_req = Hash.new { |h, k| h[k] = [] }
      cc_tests.each { |t| (test_reqs[t.id] || []).each { |rid| by_req[rid] << t } }

      if explicit_reqs && !explicit_reqs.empty?
        by_req = by_req.select { |rid, _| explicit_reqs.include?(rid) }
      end

      req_chain = by_req.map do |rid, tests|
        req = req_index[rid]
        {
          requirement_id: rid,
          statement: req&.statement,
          section: req&.section,
          format: req&.format,
          tests: tests.map { |t|
            { test_id: t.id, description: t.description, test_type: t.test_type,
              given: t.given, expect: t.expect }
          },
          per_library: adapters.map { |adefn|
            declared = declared_classes[adefn[:id]] || []
            compute_per_library_detail(adefn, tests, declared)
          },
        }
      end

      { id: cc_id, requirements: req_chain }
    end
  end

  def compute_per_library_detail(adefn, tests, declared)
    declared_bare = declared.map { |d| @index.bare_id(d) }.to_set
    results = run_tests_with_declaration_guard(adefn[:adapter], tests, declared_bare)
    p = results.count { |r| r["result"] == "pass" }
    ns = results.count { |r| r["result"] == "not-supported" }
    f = results.count { |r| r["result"] == "fail" || r["result"] == "error" }
    total = results.length
    status = self.class.classify_status(pass: p, fail: f, not_supported: ns, total: total)
    {
      library_id: adefn[:id], status: status, pass: p, total: total,
      details: tests.zip(results).map { |t, r|
        { test_id: t.id, result: r["result"],
          given: t.given, expect: t.expect,
          actual: r["actual"], api: r["api"], notes: r["notes"] }
      },
    }
  end

  def collect_profile_req_ids(profile, conf_class_details)
    ids = conf_class_details.flat_map { |cc| cc[:requirements].map { |r| r[:requirement_id] } }
    profile.additional_requirements.each { |ar| ids << ar["id"] }
    ids
  end

  def compute_adapter_profile_stats(adefn, req_ids_in_profile, ptests, declared)
    declared_bare = declared.map { |d| @index.bare_id(d) }.to_set
    test_pass = 0; test_total = 0
    req_pass = 0; req_partial = 0; req_fail = 0; req_not_supported = 0
    req_ids_in_profile.each do |rid|
      tests = ptests[rid]
      next unless tests && !tests.empty?
      results = run_tests_with_declaration_guard(adefn[:adapter], tests, declared_bare)
      p = results.count { |r| r["result"] == "pass" }
      ns = results.count { |r| r["result"] == "not-supported" }
      f = results.count { |r| r["result"] == "fail" || r["result"] == "error" }
      test_pass += p
      test_total += results.length
      status = self.class.classify_status(pass: p, fail: f, not_supported: ns, total: results.length)
      case status
      when "pass"          then req_pass += 1
      when "fail"          then req_fail += 1
      when "not-supported" then req_not_supported += 1
      else                      req_partial += 1
      end
    end
    { id: adefn[:id], test_pass: test_pass, test_total: test_total,
      req_pass: req_pass, req_partial: req_partial, req_fail: req_fail,
      req_not_supported: req_not_supported }
  end

  def build_library_output(adapters, profile_results, declared_classes, declared_profiles)
    adapters.map do |a|
      declared = declared_classes[a[:id]] || []
      profiles = declared_profiles[a[:id]] || []
      targeted = compute_target_profiles(declared, profile_results, profiles)
      notes = a[:adapter].qualification_notes || []
      { id: a[:id], name: a[:name], family: a[:family], logo: a[:logo], language: a[:language], version: a[:version],
        declared_conformance_classes: declared, target_profiles: targeted, qualification_notes: notes }
    end
  end

  def build_family_stats(adapters, requirements)
    adapters.group_by { |a| a[:family] }.map do |family, fam_adapters|
      version_ids = fam_adapters.map { |a| a[:id] }
      range_label = self.class.build_family_range_label(fam_adapters)

      stats = if fam_adapters.size == 1
        { delta_count: 0, divergent_tests: [], per_version_delta: {}, stability: "single" }
      else
        self.class.compute_family_divergence(fam_adapters, requirements)
      end

      {
        family: family,
        logo: fam_adapters.first[:logo],
        language: fam_adapters.first[:language],
        version_count: fam_adapters.size,
        version_ids: version_ids,
        range_label: range_label,
        **stats,
      }
    end
  end

  def read_declared_classes(adapter_id)
    result_file = find_result_file(adapter_id)
    return [] unless result_file
    result = @store.load(result_file)
    return [] if result.failure?
    result.data["declared_conformance_classes"] || []
  end

  def read_declared_profiles(adapter_id)
    result_file = find_result_file(adapter_id)
    return [] unless result_file
    result = @store.load(result_file)
    return [] if result.failure?
    result.data["profiles_tested"] || []
  end

  def find_result_file(adapter_id)
    @store.files_in("results/**/*.yaml").each do |f|
      next if File.basename(f) == "TEMPLATE.yaml"
      return f if File.basename(f, ".yaml") == adapter_id
    end
    nil
  end

  def compute_target_profiles(declared, profile_results, declared_profiles = [])
    if declared_profiles && !declared_profiles.empty?
      profile_set = declared_profiles.to_set
      return profile_results.select { |p| profile_set.include?(p[:id]) }
                         .map { |p| { id: p[:id], name: p[:name] } }
    end

    return profile_results.map { |p| { id: p[:id], name: p[:name] } } if declared.empty?

    declared_bare = declared.map { |d| @index.bare_id(d) }.to_set
    profile_results.select { |p|
      tc = @index.profile_traceability(p[:id])
      tc.all? { |t| declared_bare.include?(@index.bare_id(t.conformance_class)) }
    }.map { |p| { id: p[:id], name: p[:name] } }
  end

  def build_categories(requirements)
    requirements.group_by { |r| r[:category] }
                .map { |name, reqs| { name: name, count: reqs.length } }
                .sort_by { |c| c[:name] }
  end

  def run_single_test(adapter, test)
    TestTypeHandlers.run(adapter, test)
  rescue => e
    { "result" => "error", "notes" => e.message }
  end

  def run_tests_with_declaration_guard(adapter, tests, declared_bare)
    tests.map { |t|
      cc_bare = @index.bare_id(@index.class_for_test(t.id) || "")
      if !declared_bare.empty? && !declared_bare.include?(cc_bare)
        { "result" => "not-supported", "notes" => "Conformance class not declared" }
      else
        run_single_test(adapter, t)
      end
    }
  end

  def self.strip_details(full_data)
    {
      generated_at: full_data[:generated_at],
      libraries: full_data[:libraries],
      family_stats: full_data[:family_stats],
      categories: full_data[:categories],
      profiles: full_data[:profiles].map { |prof|
        p = {}
        prof.each { |k, v| p[k] = v unless k == :traceability }
        p
      },
      requirements: full_data[:requirements].map { |req|
        r = {}
        req.each { |k, v| r[k] = k == :tests ? self.strip_test_details(v) : v }
        r
      },
    }
  end

  def self.extract_details(full_data)
    {
      requirements: full_data[:requirements].map { |req|
        details = {}
        req[:tests].each do |lib_id, caps|
          lib_details = {}
          caps.each { |cap_key, cap| lib_details[cap_key] = { details: cap[:details] } if cap[:details] }
          details[lib_id] = lib_details unless lib_details.empty?
        end
        { id: req[:id], tests: details } unless details.empty?
      }.compact,
      profiles: full_data[:profiles].map { |prof|
        { id: prof[:id], traceability: prof[:traceability] } if prof[:traceability]
      }.compact,
    }
  end

  def self.strip_test_details(tests)
    tests.transform_values { |caps|
      caps.transform_values { |cap|
        { status: cap[:status], pass: cap[:pass], total: cap[:total] }
      }
    }
  end

  def self.clean_nils(obj)
    case obj
    when Hash
      obj.each_with_object({}) { |(k, v), h| h[k] = clean_nils(v) unless v.nil? }
    when Array
      obj.map { |v| clean_nils(v) }
    else
      obj
    end
  end

  def self.write_compact(data, path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.generate(clean_nils(data)))
  end

  def self.compute_family_divergence(fam_adapters, requirements)
    divergent = []
    per_version_delta = fam_adapters.each_with_object(Hash.new(0)) { |a, h| h[a[:id]] = 0 }

    requirements.each do |req|
      tests = req[:tests]
      next unless tests

      test_map = Hash.new { |h, k| h[k] = {} }
      fam_adapters.each do |a|
        caps = tests[a[:id]]
        next unless caps
        caps.each do |cap_key, cap|
          (cap[:details] || []).each do |d|
            test_map[[cap_key, d[:test_id]]][a[:id]] = d[:result] if d.key?(:result)
          end
        end
      end

      test_map.each do |(cap_key, test_id), results_by_lib|
        next unless results_by_lib.size > 1
        unique = results_by_lib.values.uniq
        next unless unique.size > 1

        tally = results_by_lib.values.tally
        majority = tally.max_by { |_, c| c }.first

        divergent << {
          req_id: req[:id],
          cap_key: cap_key,
          test_id: test_id,
          results: results_by_lib.transform_values { |r| r || "unknown" },
        }

        results_by_lib.each do |lib_id, result|
          per_version_delta[lib_id] += 1 if result != majority
        end
      end
    end

    delta_count = divergent.size
    stability = case delta_count
                when 0 then "stable"
                when 1..5 then "minor"
                else "divergent"
                end

    { delta_count: delta_count, divergent_tests: divergent, per_version_delta: per_version_delta, stability: stability }
  end

  def self.build_family_range_label(fam_adapters)
    names = fam_adapters.map { |a| a[:name] }
    return names.first if names.size == 1

    labels = names.map { |n| version_label_for(n) }.compact
    return names.first if labels.empty?
    return labels.first if labels.uniq.size == 1

    numeric = labels.select { |l| l.match?(/\A\d+(\.\d+)*\z/) }
    if numeric.size == labels.size
      sorted = labels.sort_by { |l| l.split(".").map(&:to_i) }
      return "#{sorted.first} → #{sorted.last}"
    end

    "#{labels.first} → #{labels.last}"
  end

  def self.version_label_for(name)
    paren = name[/\(([^)]+)\)/, 1]
    return paren if paren
    m = name.match(/(\d+(?:\.\d+)*)/)
    m ? m[1] : nil
  end

  # Classify a capability's overall status from its per-test result tallies.
  # All-empty input returns "not-applicable"; otherwise majority-rules with
  # partial as the catch-all when results are mixed.
  def self.classify_status(pass:, fail:, not_supported:, total:)
    return "not-applicable" if total.zero?
    return "pass"          if pass == total
    return "fail"          if fail == total
    return "not-supported" if not_supported == total
    return "partial"       if pass.positive?
    return "fail"          if fail.positive?
    "not-supported"
  end
end
