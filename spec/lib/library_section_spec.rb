# frozen_string_literal: true

require "set"
require_relative "../../lib/test_suite/matrix_context"
require_relative "../../lib/test_suite/profile"
require_relative "../../lib/test_suite/library_section"

LibraryAdapter = Struct.new(:version, :language, :notes) do
  def qualification_notes = notes || []
end

RSpec.describe LibrarySection do
  let(:adapter_with_notes) { LibraryAdapter.new("1.0", "ruby", ["ECO-1", "ECO-2"]) }

  let(:adapter_defn) do
    { id: "lib-a", name: "Library A", family: "Ruby",
      logo: "/logos/ruby.svg", language: "ruby", version: "1.0",
      adapter: adapter_with_notes }
  end

  let(:fake_index) do
    Class.new do
      def initialize(declared_bare_ids, profile_traceability_hash)
        @declared_bare = declared_bare_ids
        @profile_traceability = profile_traceability_hash
      end
      def bare_id(id) = id.sub(/\A8601-[12]:/, "")
      def profile_traceability(pid) = @profile_traceability[pid] || []
    end
  end

  let(:profile_results) do
    [
      { id: "profile:iso-8601-1-core", name: "ISO 8601-1 Core",
        traceability_class_count: 2 },
      { id: "profile:iso-8601-2-complete", name: "ISO 8601-2 Complete",
        traceability_class_count: 5 },
    ]
  end

  def ctx_with(declared_classes:, declared_profiles:, profile_traceability: {})
    MatrixContext.new(
      store: nil,
      index: fake_index.new([], profile_traceability),
      adapters: [adapter_defn],
      declared_classes: declared_classes,
      declared_profiles: declared_profiles,
      req_index: {}, req_tests: {}, class_tests: {},
      profile_tests: {}, profile_req_map: {}, test_reqs: {},
    )
  end

  it "builds one entry per adapter with metadata" do
    ctx = ctx_with(declared_classes: {}, declared_profiles: {})
    entries = described_class.new(ctx, profile_results).build
    expect(entries.length).to eq(1)
    entry = entries.first
    expect(entry[:id]).to eq("lib-a")
    expect(entry[:name]).to eq("Library A")
    expect(entry[:family]).to eq("Ruby")
    expect(entry[:logo]).to eq("/logos/ruby.svg")
    expect(entry[:language]).to eq("ruby")
    expect(entry[:version]).to eq("1.0")
  end

  it "exposes declared_conformance_classes from ctx" do
    ctx = ctx_with(
      declared_classes: { "lib-a" => ["8601-1:conf-class:calendar-date"] },
      declared_profiles: {}
    )
    entry = described_class.new(ctx, profile_results).build.first
    expect(entry[:declared_conformance_classes]).to eq(["8601-1:conf-class:calendar-date"])
  end

  it "exposes qualification_notes from the adapter" do
    ctx = ctx_with(declared_classes: {}, declared_profiles: {})
    entry = described_class.new(ctx, profile_results).build.first
    expect(entry[:qualification_notes]).to eq(["ECO-1", "ECO-2"])
  end

  it "with explicit declared_profiles, target_profiles projects only those" do
    ctx = ctx_with(
      declared_classes: {},
      declared_profiles: { "lib-a" => ["profile:iso-8601-1-core"] }
    )
    entry = described_class.new(ctx, profile_results).build.first
    expect(entry[:target_profiles]).to eq([
      { id: "profile:iso-8601-1-core", name: "ISO 8601-1 Core" }
    ])
  end

  it "with no declared classes or profiles, all profile_results are projected" do
    ctx = ctx_with(declared_classes: {}, declared_profiles: {})
    entry = described_class.new(ctx, profile_results).build.first
    expect(entry[:target_profiles].length).to eq(2)
    expect(entry[:target_profiles].map { |p| p[:id] }).to contain_exactly(
      "profile:iso-8601-1-core", "profile:iso-8601-2-complete"
    )
  end

  it "with declared classes but no profiles, projects only profiles whose traceability is fully declared" do
    index = Class.new do
      def bare_id(id) = id.sub(/\A8601-[12]:/, "")
      def profile_traceability(pid)
        {
          "profile:iso-8601-1-core" => [
            Profile::TraceabilityEntry.new("8601-1:conf-class:calendar-date", []),
            Profile::TraceabilityEntry.new("8601-1:conf-class:time", []),
          ],
          "profile:iso-8601-2-complete" => [
            Profile::TraceabilityEntry.new("8601-1:conf-class:calendar-date", []),
            Profile::TraceabilityEntry.new("8601-2:conf-class:arithmetic", []),
          ],
        }[pid] || []
      end
    end.new
    ctx = MatrixContext.new(
      store: nil, index: index, adapters: [adapter_defn],
      declared_classes: { "lib-a" => ["8601-1:conf-class:calendar-date", "8601-1:conf-class:time"] },
      declared_profiles: {},
      req_index: {}, req_tests: {}, class_tests: {},
      profile_tests: {}, profile_req_map: {}, test_reqs: {},
    )
    entry = described_class.new(ctx, profile_results).build.first
    expect(entry[:target_profiles].map { |p| p[:id] }).to eq(["profile:iso-8601-1-core"])
  end

  it "uses an empty declared list when adapter has no entry" do
    ctx = MatrixContext.new(
      store: nil,
      index: Class.new do
        def bare_id(id) = id
        def profile_traceability(_pid) = []
      end.new,
      adapters: [adapter_defn],
      declared_classes: {},
      declared_profiles: {},
      req_index: {}, req_tests: {}, class_tests: {},
      profile_tests: {}, profile_req_map: {}, test_reqs: {},
    )
    entry = described_class.new(ctx, profile_results).build.first
    expect(entry[:declared_conformance_classes]).to eq([])
    expect(entry[:target_profiles].length).to eq(2)
  end
end

