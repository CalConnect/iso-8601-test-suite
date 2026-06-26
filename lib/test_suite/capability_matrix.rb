# frozen_string_literal: true

require 'yaml'

# Capability matrix orchestrator.
#
# Wires together the cross-referenced data (MatrixContext), drives the
# per-slice section builders, and assembles the final matrix payload.
# All per-slice logic (requirements, profiles, libraries, family
# divergence, output projection) lives in dedicated modules; this class
# only sequences them.
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

  def initialize(store, index, suite)
    @store = store
    @index = index
    @suite = suite
  end

  def generate(adapter_defs: ADAPTER_DEFS, on_progress: nil)
    ctx = build_context(adapter_defs, on_progress)
    requirements = RequirementsSection.new(ctx, on_progress: on_progress).build
    profiles = ProfileSection.new(ctx).build

    {
      generated_at: Time.now.utc.iso8601,
      libraries: LibrarySection.new(ctx, profiles).build,
      family_stats: FamilyDivergence.build(ctx.adapters, requirements),
      requirements: requirements,
      profiles: profiles,
      categories: build_categories(requirements),
    }
  end

  private

  def build_context(adapter_defs, on_progress)
    adapters = load_adapters(adapter_defs, on_progress)
    declared_classes = adapters.to_h { |a| [a[:id], read_declared_classes(a[:id])] }
    declared_profiles = adapters.to_h { |a| [a[:id], read_declared_profiles(a[:id])] }

    req_index = build_requirements_index
    all_tests = @suite.all_tests
    test_reqs = @index.test_reqs
    req_tests = invert_tests_by_req(all_tests, test_reqs)
    class_tests = group_tests_by_class(all_tests)
    profile_tests = build_profile_tests(test_reqs)
    profile_req_map = build_profile_req_map(class_tests, test_reqs)

    MatrixContext.new(
      store: @store, index: @index,
      adapters: adapters,
      declared_classes: declared_classes,
      declared_profiles: declared_profiles,
      req_index: req_index,
      req_tests: req_tests,
      class_tests: class_tests,
      profile_tests: profile_tests,
      profile_req_map: profile_req_map,
      test_reqs: test_reqs,
    )
  end

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

  def invert_tests_by_req(all_tests, test_reqs)
    req_tests = Hash.new { |h, k| h[k] = [] }
    all_tests.each do |test|
      (test_reqs[test.id] || []).each { |req_id| req_tests[req_id] << test }
    end
    req_tests
  end

  def group_tests_by_class(all_tests)
    class_tests = Hash.new { |h, k| h[k] = [] }
    all_tests.each do |test|
      cc_id = @index.class_for_test(test.id)
      class_tests[cc_id] << test if cc_id
    end
    class_tests
  end

  def build_profile_tests(test_reqs)
    @index.profile_ids.each_with_object({}) do |pid, hash|
      tests = @suite.tests_for_profile(pid)
      by_req = Hash.new { |h, k| h[k] = [] }
      tests.each { |t| (test_reqs[t.id] || []).each { |rid| by_req[rid] << t } }
      hash[pid] = by_req
    end
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

  def read_declared_classes(adapter_id)
    load_declared(adapter_id, "declared_conformance_classes")
  end

  def read_declared_profiles(adapter_id)
    load_declared(adapter_id, "profiles_tested")
  end

  def load_declared(adapter_id, key)
    result_file = find_result_file(adapter_id)
    return [] unless result_file
    result = @store.load(result_file)
    return [] if result.failure?
    result.data[key] || []
  end

  def find_result_file(adapter_id)
    @store.files_in("results/**/*.yaml").each do |f|
      next if File.basename(f) == "TEMPLATE.yaml"
      return f if File.basename(f, ".yaml") == adapter_id
    end
    nil
  end

  def build_categories(requirements)
    requirements.group_by { |r| r[:category] }
                .map { |name, reqs| { name: name, count: reqs.length } }
                .sort_by { |c| c[:name] }
  end
end
