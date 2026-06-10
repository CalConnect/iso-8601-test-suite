# frozen_string_literal: true

require 'json'
require 'fileutils'

class CapabilityMatrix
  ADAPTER_DEFS = [
    { id: "ruby-date",       name: "Ruby Date/DateTime/Time",       logo: "/logos/ruby.svg",       adapter: "ruby-date" },
    { id: "ruby-date-40",    name: "Ruby 4.0 Date/DateTime/Time",   logo: "/logos/ruby.svg",       adapter: "exec:#{File.expand_path('~/.local/share/mise/installs/ruby/4.0.5/bin/ruby')} adapters/ruby-date-40.rb" },
    { id: "python-datetime", name: "Python datetime",               logo: "/logos/python.svg",     adapter: "exec:python3 adapters/python-datetime.py" },
    { id: "node-datetime",   name: "JavaScript Date",               logo: "/logos/javascript.svg", adapter: "exec:node adapters/node-datetime.js" },
  ].freeze

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
    all_tests = @suite.all_tests
    test_reqs = @index.test_reqs

    req_tests = build_req_tests(all_tests, test_reqs)
    class_tests = build_class_tests(all_tests)
    profile_tests = build_profile_tests(test_reqs)
    profile_req_map = build_profile_req_map(class_tests, test_reqs)

    requirements_output = build_requirements(
      adapters, req_index, req_tests, profile_req_map, on_progress
    )

    profile_results = build_profile_results(
      adapters, profile_tests, test_reqs, req_index
    )

    {
      generated_at: Time.now.utc.iso8601,
      libraries: build_library_output(adapters, profile_results),
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

  def clause_section(clause)
    return nil unless clause
    s = clause.to_s
    if s.include?(":clause:")
      section = s.sub(/.*:clause:/, "").sub(/:tech:.*$/, "")
      part_match = s.match(/8601:-([12]):/)
      part = part_match ? part_match[1] : "?"
      "Part #{part} §#{section}"
    else
      s
    end
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
        reqs[r["id"]] = {
          category: class_name,
          statement: r["statement"]&.strip,
          format: r["format"],
          clause: r["clause"],
          section: clause_section(r["clause"]),
          pattern: r["pattern"],
          part: part,
          source_class: data["id"],
        }
      end
    end

    @store.files_in("profiles/**/*.yaml").each do |f|
      next if File.basename(f) == "TEMPLATE.yaml"
      result = @store.load(f)
      next unless result.success?
      data = result.data
      profile_id = data["id"]
      profile_name = data["name"]
      (data["additional_requirements"] || []).each do |r|
        reqs[r["id"]] = {
          category: "Profile-Specific (#{profile_name})",
          statement: r["statement"]&.strip,
          format: r["format"],
          clause: r["clause"],
          section: clause_section(r["clause"]),
          pattern: r["pattern"],
          part: "profile",
          source_class: nil,
          source_profile: profile_id,
        }
      end
    end

    reqs
  end

  def build_req_tests(all_tests, test_reqs)
    req_tests = Hash.new { |h, k| h[k] = [] }
    all_tests.each do |test|
      (test_reqs[test["id"]] || []).each do |req_id|
        req_tests[req_id] << test
      end
    end
    req_tests
  end

  def build_class_tests(all_tests)
    class_tests = Hash.new { |h, k| h[k] = [] }
    all_tests.each do |test|
      cc_id = @index.class_for_test(test["id"])
      class_tests[cc_id] << test if cc_id
    end
    class_tests
  end

  def build_profile_tests(test_reqs)
    profile_tests = {}
    @index.profile_ids.each do |pid|
      tests = @suite.tests_for_profile(pid)
      by_req = Hash.new { |h, k| h[k] = [] }
      tests.each { |t| (test_reqs[t["id"]] || []).each { |rid| by_req[rid] << t } }
      profile_tests[pid] = by_req
    end
    profile_tests
  end

  def build_profile_req_map(class_tests, test_reqs)
    profile_req_map = {}
    @index.profile_ids.each do |pid|
      data = @index.profiles[pid]
      next unless data

      @index.profile_traceability(pid).each do |tc|
        explicit_reqs = tc[:requirements]
        if explicit_reqs && !explicit_reqs.empty?
          explicit_reqs.each { |rid|
            (profile_req_map[rid] ||= []) << { id: pid, name: data["name"] }
          }
        else
          bare = @index.bare_id(tc[:conformance_class])
          cc_tests = class_tests[bare] || []
          cc_tests.each { |t| (test_reqs[t["id"]] || []).each { |rid|
            (profile_req_map[rid] ||= []) << { id: pid, name: data["name"] }
          }}
        end
      end

      (data["additional_requirements"] || []).each do |ar|
        (profile_req_map[ar["id"]] ||= []) << { id: pid, name: data["name"] }
      end
    end
    profile_req_map.transform_values! { |v| v.uniq { |p| p[:id] } }
    profile_req_map
  end

  def build_requirements(adapters, req_index, req_tests, profile_req_map, on_progress)
    all_req_ids = req_index.keys.sort
    (req_tests.keys - all_req_ids).sort.each { |rid| all_req_ids << rid }

    requirements_output = []
    all_req_ids.each do |req_id|
      req_info = req_index[req_id] || {}
      tests_for_req = req_tests[req_id]
      next if tests_for_req.empty?

      tests_by_type = tests_for_req.group_by { |t| t["test_type"] }

      req_entry = {
        id: req_id,
        category: req_info[:category] || "Unknown",
        statement: req_info[:statement],
        format: req_info[:format],
        clause: req_info[:clause],
        section: req_info[:section],
        part: req_info[:part],
        pattern: req_info[:pattern],
        source_profile: req_info[:source_profile],
        profiles: profile_req_map[req_id] || [],
        tests: {},
      }

      adapters.each do |adefn|
        capabilities = build_adapter_capabilities(adefn, tests_by_type)
        req_entry[:tests][adefn[:id]] = capabilities unless capabilities.empty?
      end

      requirements_output << req_entry
      on_progress&.call(:requirement, req_id, req_info, adapters, req_entry)
    end
    requirements_output
  end

  def build_adapter_capabilities(adefn, tests_by_type)
    adapter = adefn[:adapter]
    capabilities = {}

    tests_by_type.each do |test_type, tests|
      cap_key = TEST_TYPE_TO_CAPABILITY[test_type] || test_type
      results = tests.map { |t| run_single_test(adapter, t) }
      pass_count = results.count { |r| r["result"] == "pass" }
      total = results.length

      if total > 0
        capabilities[cap_key] = {
          status: pass_count == total ? "pass" : (pass_count > 0 ? "partial" : "fail"),
          pass: pass_count,
          total: total,
          details: tests.zip(results).map { |t, r|
            {
              test_id: t["id"], description: t["description"], test_type: t["test_type"],
              given: t["given"], expect: t["expect"],
              result: r["result"], api: r["api"], notes: r["notes"], actual: r["actual"],
            }
          },
        }
      end
    end
    capabilities
  end

  def build_profile_results(adapters, profile_tests, test_reqs, req_index)
    @index.profile_ids.map do |pid|
      data = @index.profiles[pid]
      next unless data

      ptests = profile_tests[pid] || {}

      conf_class_details = build_traceability_details(pid, adapters, test_reqs, req_index)
      req_ids_in_profile = collect_profile_req_ids(data, conf_class_details)

      adapter_results = adapters.map do |adefn|
        compute_adapter_profile_stats(adefn, req_ids_in_profile, ptests)
      end

      {
        id: pid,
        name: data["name"],
        description: data["description"]&.strip,
        source: data["source"],
        logo: PROFILE_ORG_LOGOS[pid],
        traceability_class_count: @index.profile_traceability(pid).length,
        additional_requirements: (data["additional_requirements"] || []).map { |r|
          { id: r["id"], statement: r["statement"]&.strip }
        },
        adapter_results: adapter_results,
        traceability: conf_class_details,
      }
    end.compact
  end

  def build_traceability_details(profile_id, adapters, test_reqs, req_index)
    @index.profile_traceability(profile_id).map do |tc|
      cc_id = tc[:conformance_class]
      explicit_reqs = tc[:requirements]

      bare = @index.bare_id(cc_id)
      cc_result = @store.load(@index.conf_class_ids[bare]) if @index.conf_class_ids.key?(bare)
      cc_tests = cc_result&.success? ? (cc_result.data["tests"] || []) : []

      by_req = Hash.new { |h, k| h[k] = [] }
      cc_tests.each { |t| (test_reqs[t["id"]] || []).each { |rid| by_req[rid] << t } }

      if explicit_reqs && !explicit_reqs.empty?
        by_req = by_req.select { |rid, _| explicit_reqs.include?(rid) }
      end

      req_chain = by_req.map do |rid, tests|
        req_info = req_index[rid] || {}
        {
          requirement_id: rid,
          statement: req_info[:statement],
          section: req_info[:section],
          format: req_info[:format],
          tests: tests.map { |t|
            { test_id: t["id"], description: t["description"], test_type: t["test_type"],
              given: t["given"], expect: t["expect"] }
          },
          per_library: adapters.map { |adefn|
            compute_per_library_detail(adefn, tests)
          },
        }
      end

      { id: cc_id, requirements: req_chain }
    end
  end

  def compute_per_library_detail(adefn, tests)
    results = tests.map { |t| run_single_test(adefn[:adapter], t) }
    p = results.count { |r| r["result"] == "pass" }
    total = results.length
    status = total == 0 ? "not-applicable" : (p == total ? "pass" : (p > 0 ? "partial" : "fail"))
    {
      library_id: adefn[:id], status: status, pass: p, total: total,
      details: tests.zip(results).map { |t, r|
        { test_id: t["id"], result: r["result"],
          given: t["given"], expect: t["expect"],
          actual: r["actual"], api: r["api"], notes: r["notes"] }
      },
    }
  end

  def collect_profile_req_ids(data, conf_class_details)
    ids = conf_class_details.flat_map { |cc| cc[:requirements].map { |r| r[:requirement_id] } }
    (data["additional_requirements"] || []).each { |ar| ids << ar["id"] }
    ids
  end

  def compute_adapter_profile_stats(adefn, req_ids_in_profile, ptests)
    test_pass = 0; test_total = 0
    req_pass = 0; req_partial = 0; req_fail = 0
    req_ids_in_profile.each do |rid|
      tests = ptests[rid]
      next unless tests && !tests.empty?
      results = tests.map { |t| run_single_test(adefn[:adapter], t) }
      p = results.count { |r| r["result"] == "pass" }
      test_pass += p
      test_total += results.length
      if p == results.length
        req_pass += 1
      elsif p > 0
        req_partial += 1
      else
        req_fail += 1
      end
    end
    { id: adefn[:id], test_pass: test_pass, test_total: test_total,
      req_pass: req_pass, req_partial: req_partial, req_fail: req_fail }
  end

  def build_library_output(adapters, profile_results)
    adapters.map do |a|
      targeted = profile_results.select { |p|
        ar = p[:adapter_results].find { |r| r[:id] == a[:id] }
        ar && ar[:test_total] > 0
      }.map { |p| { id: p[:id], name: p[:name] } }
      { id: a[:id], name: a[:name], logo: a[:logo], language: a[:language], version: a[:version],
        target_profiles: targeted }
    end
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

  def self.strip_details(full_data)
    {
      generated_at: full_data[:generated_at],
      libraries: full_data[:libraries],
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
end
