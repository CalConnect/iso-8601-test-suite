# frozen_string_literal: true

class SuiteIndex
  attr_reader :req_ids, :req_class_ids, :conf_class_ids, :conf_test_ids
  attr_reader :profile_req_ids, :profile_ids, :source_map, :profiles
  attr_reader :dependencies, :test_reqs

  def initialize(store)
    @store = store
    @req_ids = {}
    @req_class_ids = {}
    @conf_class_ids = {}
    @conf_test_ids = {}
    @profile_req_ids = {}
    @profile_ids = []
    @source_map = {}
    @profiles = {}
    @dependencies = {}
    @test_reqs = {}
    @loaded = false
  end

  def load_all
    return self if @loaded
    index_requirements
    index_tests
    index_profiles
    @loaded = true
    self
  end

  def class_for_test(test_id)
    @test_to_class[test_id]
  end

  def file_for_test(test_id)
    @conf_test_ids[test_id]
  end

  def all_req_ids
    @req_ids.keys + @profile_req_ids.keys
  end

  def total_test_count
    @conf_test_ids.length
  end

  def bare_id(id)
    id.to_s.sub(/\A\d+-\d+:/, "")
  end

  def resolve_class(id)
    bare = bare_id(id)
    file = @conf_class_ids[bare]
    return nil unless file
    [file, bare]
  end

  def part_for_file(path)
    path.include?("8601-1") ? "8601-1" : "8601-2"
  end

  # Returns [{ conformance_class: "conf-class:x", requirements: ["req:a", ...] }]
  # for a given profile. Handles traceability and legacy conformance_classes.
  def profile_traceability(profile_id)
    data = @profiles[profile_id]
    return [] unless data

    if data["traceability"] && !data["traceability"].empty?
      data["traceability"].map { |tc|
        { conformance_class: tc["conformance_class"], requirements: tc["requirements"] || [] }
      }
    elsif data["conformance_classes"]
      (data["conformance_classes"] || []).map { |cc|
        { conformance_class: cc, requirements: [] }
      }
    else
      []
    end
  end

  private

  def index_requirements
    @store.files_in("requirements/**/*.yaml").each do |f|
      result = @store.load(f)
      next unless result.success?

      data = result.data
      id = data["id"]
      @req_class_ids[id] = f
      @source_map[f] = data["source"] if data["source"]
      @dependencies[id] = data["dependencies"] || []

      (data["requirements"] || []).each do |r|
        rid = r["id"]
        @req_ids[rid] = f if rid
      end
    end
  end

  def index_tests
    @test_to_class = {}
    @store.files_in("tests/**/*.yaml").each do |f|
      result = @store.load(f)
      next unless result.success?

      data = result.data
      id = data["id"]
      part = part_for_file(f)
      @conf_class_ids[id] = f
      @source_map[f] = data["source"] if data["source"]

      (data["tests"] || []).each do |t|
        tid = t["id"]
        next unless tid
        @conf_test_ids[tid] = f
        @test_to_class[tid] = id
        @test_reqs[tid] = t["requirements"] || []
      end
    end
  end

  def index_profiles
    @store.files_in("profiles/**/*.yaml").each do |f|
      next if File.basename(f) == "TEMPLATE.yaml"
      result = @store.load(f)
      next unless result.success?

      data = result.data
      id = data["id"]
      @profile_ids << id
      @profiles[id] = data
      @source_map[f] = data["source"] if data["source"]

      (data["additional_requirements"] || []).each do |r|
        rid = r["id"]
        @profile_req_ids[rid] = f if rid
      end

      (data["additional_tests"] || []).each do |t|
        tid = t["id"]
        next unless tid
        @conf_test_ids[tid] = f
        @test_to_class[tid] = id
        @test_reqs[tid] = t["requirements"] || []
      end
    end
  end
end
