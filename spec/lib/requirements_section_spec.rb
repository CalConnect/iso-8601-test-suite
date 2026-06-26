# frozen_string_literal: true

require "set"
require_relative "../../lib/test_suite/matrix_context"
require_relative "../../lib/test_suite/adapter_runner"
require_relative "../../lib/test_suite/requirement"
require_relative "../../lib/test_suite/test"
require_relative "../../lib/test_suite/test_status"
require_relative "../../lib/test_suite/requirements_section"

CannedAdapter = Struct.new(:version, :language, :next_results) do
  def qualification_notes = []
end

RSpec.describe RequirementsSection do
  let(:fake_index) do
    Class.new do
      def initialize(mapping) = @mapping = mapping
      def bare_id(id) = id
      def class_for_test(tid) = @mapping[tid]
    end.new({ "conf-test:t-001" => "conf-class:cal" })
  end

  let(:adapter) { CannedAdapter.new("1.0", "ruby", [{ "result" => "pass" }]) }
  let(:adapter_defn) { { id: "lib-a", adapter: adapter } }

  let(:requirement) do
    Requirement.new(
      { "id" => "req:cal-date-basic",
        "statement" => "Calendar date in basic format.",
        "format" => "YYYYMMDD",
        "clause" => "iso:8601:-1:ed-1:en:clause:5.2.2.1",
        "pattern" => "^[0-9]{8}$" },
      source_class: "req-class:calendar-date",
      category: "Calendar date",
      part: "1"
    )
  end

  let(:test) do
    Test.new(
      "id" => "conf-test:t-001",
      "test_type" => "validity",
      "requirements" => ["req:cal-date-basic"],
      "given" => { "expression" => "20260626" },
      "expect" => { "valid" => true }
    )
  end

  let(:ctx) do
    MatrixContext.new(
      store: nil, index: fake_index,
      adapters: [adapter_defn],
      declared_classes: {},
      declared_profiles: {},
      req_index: { "req:cal-date-basic" => requirement },
      req_tests: { "req:cal-date-basic" => [test] },
      class_tests: {},
      profile_tests: {},
      profile_req_map: { "req:cal-date-basic" => [{ id: "profile:p1", name: "P1" }] },
      test_reqs: { "conf-test:t-001" => ["req:cal-date-basic"] },
    )
  end

  before { stub_const("TestTypeHandlers", canned_handlers) }

  let(:canned_handlers) do
    Module.new do
      module_function
      def run(_adapter, _test) = { "result" => "pass", "api" => "Date.parse", "actual" => "ok" }
    end
  end

  it "builds one entry per requirement that has tests" do
    entries = described_class.new(ctx).build
    expect(entries.length).to eq(1)
    expect(entries.first[:id]).to eq("req:cal-date-basic")
  end

  it "projects requirement metadata into the entry" do
    entry = described_class.new(ctx).build.first
    expect(entry[:category]).to eq("Calendar date")
    expect(entry[:format]).to eq("YYYYMMDD")
    expect(entry[:pattern]).to eq("^[0-9]{8}$")
    expect(entry[:profiles]).to eq([{ id: "profile:p1", name: "P1" }])
  end

  it "groups test results by capability key derived from test_type" do
    entry = described_class.new(ctx).build.first
    capabilities = entry[:tests]["lib-a"]
    expect(capabilities).to have_key("parse_general")
    cap = capabilities["parse_general"]
    expect(cap[:status]).to eq("pass")
    expect(cap[:pass]).to eq(1)
    expect(cap[:total]).to eq(1)
    expect(cap[:details].first[:test_id]).to eq("conf-test:t-001")
    expect(cap[:details].first[:result]).to eq("pass")
  end

  it "invokes the progress callback for each requirement" do
    observed = []
    described_class.new(ctx, on_progress: ->(kind, req_id, _req, _adapters, _entry) {
      observed << [kind, req_id]
    }).build
    expect(observed).to eq([[:requirement, "req:cal-date-basic"]])
  end

  it "skips requirements with no associated tests" do
    orphan = Requirement.new({ "id" => "req:orphan", "statement" => "no tests" })
    ctx_with_orphan = MatrixContext.new(
      store: nil, index: fake_index,
      adapters: [adapter_defn],
      declared_classes: {}, declared_profiles: {},
      req_index: { "req:cal-date-basic" => requirement, "req:orphan" => orphan },
      req_tests: { "req:cal-date-basic" => [test] },
      class_tests: {}, profile_tests: {}, profile_req_map: {}, test_reqs: {},
    )
    entries = described_class.new(ctx_with_orphan).build
    expect(entries.map { |e| e[:id] }).to eq(["req:cal-date-basic"])
  end

  it "includes requirements referenced from tests but absent from req_index" do
    ctx_with_phantom = MatrixContext.new(
      store: nil, index: fake_index,
      adapters: [adapter_defn],
      declared_classes: {}, declared_profiles: {},
      req_index: {},
      req_tests: { "req:phantom" => [test] },
      class_tests: {}, profile_tests: {}, profile_req_map: {}, test_reqs: {},
    )
    entries = described_class.new(ctx_with_phantom).build
    expect(entries.first[:id]).to eq("req:phantom")
    expect(entries.first[:category]).to eq("Unknown")
  end

  it "respects the per-adapter declaration guard" do
    fake_index_with_class = Class.new do
      def bare_id(id) = id
      def class_for_test(_tid) = "conf-class:declared"
    end.new
    undeclared_adapter = CannedAdapter.new("1.0", "ruby", [])
    ctx_guarded = MatrixContext.new(
      store: nil, index: fake_index_with_class,
      adapters: [{ id: "lib-guarded", adapter: undeclared_adapter }],
      declared_classes: { "lib-guarded" => ["conf-class:other"].to_set },
      declared_profiles: {},
      req_index: { "req:cal-date-basic" => requirement },
      req_tests: { "req:cal-date-basic" => [test] },
      class_tests: {}, profile_tests: {}, profile_req_map: {}, test_reqs: {},
    )
    entry = described_class.new(ctx_guarded).build.first
    capabilities = entry[:tests]["lib-guarded"]
    expect(capabilities["parse_general"][:details].first[:result]).to eq("not-supported")
  end
end
