# frozen_string_literal: true

require "set"
require_relative "../../lib/test_suite/adapter_def"
require_relative "../../lib/test_suite/load_result"
require_relative "../../lib/test_suite/matrix_context"
require_relative "../../lib/test_suite/adapter_runner"
require_relative "../../lib/test_suite/profile"
require_relative "../../lib/test_suite/requirement"
require_relative "../../lib/test_suite/test"
require_relative "../../lib/test_suite/test_status"
require_relative "../../lib/test_suite/profile_section"

ProfileAdapter = Struct.new(:version, :language) do
  def qualification_notes = []
end

RSpec.describe ProfileSection do
  let(:profile) do
    Profile.new(
      "id" => "profile:iso-8601-1-core",
      "name" => "ISO 8601-1 Core",
      "description" => "  Core Part 1 profile.  ",
      "source" => "ISO 8601-1:2026",
      "traceability" => [
        { "conformance_class" => "8601-1:conf-class:calendar-date",
          "requirements" => ["req:cal-date-basic"] },
      ],
      "additional_requirements" => [
        { "id" => "req:core-additional", "statement" => "  Additional req.  " },
      ]
    )
  end

  let(:requirement) do
    Requirement.new(
      { "id" => "req:cal-date-basic",
        "statement" => "Calendar date basic format.",
        "format" => "YYYYMMDD",
        "clause" => "iso:8601:-1:ed-1:en:clause:5.2.2.1" },
      source_class: "req-class:calendar-date",
      category: "Calendar date",
      part: "1"
    )
  end

  let(:test) do
    Test.new(
      "id" => "conf-test:cal-date-001",
      "description" => "Parses basic date.",
      "test_type" => "validity",
      "requirements" => ["req:cal-date-basic"],
      "given" => { "expression" => "20260626" },
      "expect" => { "valid" => true }
    )
  end

  let(:adapter_defn) do
    AdapterDef.new(
      id: "lib-a", name: "Library A", family: "Ruby",
      logo: "/logos/ruby.svg", language: "ruby", version: "1.0",
      adapter: ProfileAdapter.new("1.0", "ruby"),
    )
  end

  let(:fake_index) do
    Class.new do
      def initialize(profiles_hash, profile_traceability_hash, conf_class_files)
        @profiles_hash = profiles_hash
        @profile_traceability = profile_traceability_hash
        @conf_class_files = conf_class_files
      end
      def profile_ids = @profiles_hash.keys
      def profiles = @profiles_hash
      def profile_traceability(pid) = @profile_traceability[pid] || []
      def bare_id(id) = id.sub(/\A8601-[12]:/, "")
      def conf_class_ids = @conf_class_files
    end.new(
      { "profile:iso-8601-1-core" => profile },
      { "profile:iso-8601-1-core" => profile.traceability_entries },
      { "conf-class:calendar-date" => "tests/8601-1/calendar-date.yaml" }
    )
  end

  let(:fake_store) do
    Class.new do
      def initialize(cc_file_data) = @cc_file_data = cc_file_data
      def load(path)
        data = @cc_file_data[path]
        data ? LoadResult.success(data) : LoadResult.failure("not found: #{path}")
      end
    end.new(
      "tests/8601-1/calendar-date.yaml" => {
        "tests" => [
          { "id" => "conf-test:cal-date-001",
            "description" => "Parses basic date.",
            "test_type" => "validity",
            "requirements" => ["req:cal-date-basic"],
            "given" => { "expression" => "20260626" },
            "expect" => { "valid" => true } }
        ]
      }
    )
  end

  let(:ctx) do
    MatrixContext.new(
      store: fake_store, index: fake_index,
      adapters: [adapter_defn],
      declared_classes: {},
      declared_profiles: {},
      req_index: { "req:cal-date-basic" => requirement },
      req_tests: {},
      class_tests: { "conf-class:calendar-date" => [test] },
      profile_tests: {
        "profile:iso-8601-1-core" => { "req:cal-date-basic" => [test] },
      },
      profile_req_map: {},
      test_reqs: { "conf-test:cal-date-001" => ["req:cal-date-basic"] },
    )
  end

  before do
    stub_const("TestTypeHandlers", Module.new do
      module_function
      def run(_adapter, _test) = { "result" => "pass", "api" => "Date.parse", "actual" => "2026-06-26" }
    end)
  end

  it "builds one slice per profile_id" do
    slices = described_class.new(ctx).build
    expect(slices.length).to eq(1)
    expect(slices.first[:id]).to eq("profile:iso-8601-1-core")
  end

  it "projects profile metadata into the slice" do
    slice = described_class.new(ctx).build.first
    expect(slice[:name]).to eq("ISO 8601-1 Core")
    expect(slice[:description]).to eq("Core Part 1 profile.")
    expect(slice[:source]).to eq("ISO 8601-1:2026")
    expect(slice[:logo]).to eq("/logos/iso-red.svg")
    expect(slice[:traceability_class_count]).to eq(1)
  end

  it "exposes additional_requirements with stripped statements" do
    slice = described_class.new(ctx).build.first
    expect(slice[:additional_requirements]).to eq([
      { id: "req:core-additional", statement: "Additional req." }
    ])
  end

  it "builds a traceability chain per conf-class with per-requirement tests" do
    slice = described_class.new(ctx).build.first
    expect(slice[:traceability].length).to eq(1)
    cc = slice[:traceability].first
    expect(cc[:id]).to eq("8601-1:conf-class:calendar-date")
    expect(cc[:requirements].length).to eq(1)
    req_entry = cc[:requirements].first
    expect(req_entry[:requirement_id]).to eq("req:cal-date-basic")
    expect(req_entry[:tests].first[:test_id]).to eq("conf-test:cal-date-001")
  end

  it "records per-library detail for each test in the chain" do
    slice = described_class.new(ctx).build.first
    detail = slice[:traceability].first[:requirements].first[:per_library].first
    expect(detail[:library_id]).to eq("lib-a")
    expect(detail[:status]).to eq("pass")
    expect(detail[:pass]).to eq(1)
    expect(detail[:total]).to eq(1)
    expect(detail[:details].first[:result]).to eq("pass")
  end

  it "aggregates per-adapter stats across every requirement in the profile" do
    slice = described_class.new(ctx).build.first
    stats = slice[:adapter_results].first
    expect(stats[:id]).to eq("lib-a")
    expect(stats[:test_pass]).to eq(1)
    expect(stats[:test_total]).to eq(1)
    expect(stats[:req_pass]).to eq(1)
    expect(stats[:req_fail]).to eq(0)
    expect(stats[:req_partial]).to eq(0)
    expect(stats[:req_not_supported]).to eq(0)
  end

  it "classifies not-supported requirement status into req_not_supported" do
    breaking = ProfileAdapter.new("1.0", "ruby")
    breaking.define_singleton_method(:version) { raise "nope" }
    stub_const("TestTypeHandlers", Module.new do
      module_function
      def run(_adapter, _test) = raise(StandardError, "adapter error")
    end)
    ctx_breaking = MatrixContext.new(
      store: fake_store, index: fake_index,
      adapters: [AdapterDef.new(
        id: "lib-broken", name: "Broken", family: "Ruby",
        logo: "/logos/ruby.svg", language: "ruby", version: "1.0",
        adapter: breaking,
      )],
      declared_classes: { "lib-broken" => ["conf-class:calendar-date"].to_set },
      declared_profiles: {},
      req_index: { "req:cal-date-basic" => requirement },
      req_tests: {},
      class_tests: { "conf-class:calendar-date" => [test] },
      profile_tests: { "profile:iso-8601-1-core" => { "req:cal-date-basic" => [test] } },
      profile_req_map: {},
      test_reqs: { "conf-test:cal-date-001" => ["req:cal-date-basic"] },
    )
    slice = described_class.new(ctx_breaking).build.first
    stats = slice[:adapter_results].first
    expect(stats[:req_fail]).to eq(1)
  end

  it "skips profile_ids whose Profile can't be loaded" do
    ctx_with_nil = MatrixContext.new(
      store: fake_store,
      index: Class.new do
        def profile_ids = ["profile:missing"]
        def profiles = {}
        def profile_traceability(_pid) = []
        def bare_id(id) = id
        def conf_class_ids = {}
      end.new,
      adapters: [adapter_defn],
      declared_classes: {}, declared_profiles: {},
      req_index: {}, req_tests: {}, class_tests: {},
      profile_tests: {}, profile_req_map: {}, test_reqs: {},
    )
    expect(described_class.new(ctx_with_nil).build).to eq([])
  end
end
