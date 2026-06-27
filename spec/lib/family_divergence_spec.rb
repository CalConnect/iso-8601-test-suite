# frozen_string_literal: true

require_relative "../../lib/test_suite/adapter_def"
require_relative "../../lib/test_suite/family_divergence"

def adapter_def(id:, name:, family:, logo: "/logos/x.svg", language: "x", version: "1.0", adapter: nil)
  AdapterDef.new(id: id, name: name, family: family, logo: logo,
                 language: language, version: version, adapter: adapter)
end

RSpec.describe FamilyDivergence do
  describe ".version_label_for" do
    it "extracts a numeric version from the name" do
      expect(described_class.version_label_for("Ruby 3.4 Date")).to eq("3.4")
      expect(described_class.version_label_for("Node.js 18 Date")).to eq("18")
    end

    it "prefers a parenthetical qualifier when present" do
      expect(described_class.version_label_for("C strftime (BSD)")).to eq("BSD")
      expect(described_class.version_label_for("C++ std::chrono (Apple)")).to eq("Apple")
    end

    it "returns nil when no version token is present" do
      expect(described_class.version_label_for("Generic Adapter")).to be_nil
    end
  end

  describe ".build_family_range_label" do
    it "returns the single name when the family has one member" do
      fam = [adapter_def(id: "rust-1", name: "Rust chrono 0.4.19", family: "Rust")]
      expect(described_class.build_family_range_label(fam)).to eq("Rust chrono 0.4.19")
    end

    it "renders 'first → last' for a numeric range" do
      fam = [
        adapter_def(id: "ruby-30", name: "Ruby 3.0 Date", family: "Ruby"),
        adapter_def(id: "ruby-32", name: "Ruby 3.2 Date", family: "Ruby"),
        adapter_def(id: "ruby-31", name: "Ruby 3.1 Date", family: "Ruby"),
      ]
      expect(described_class.build_family_range_label(fam)).to eq("3.0 → 3.2")
    end

    it "returns the single distinct label when all members share it" do
      fam = [
        adapter_def(id: "a", name: "Adapter (glibc)", family: "C"),
        adapter_def(id: "b", name: "Other (glibc)", family: "C"),
      ]
      expect(described_class.build_family_range_label(fam)).to eq("glibc")
    end

    it "falls back to first → last when labels are non-numeric" do
      fam = [
        adapter_def(id: "a", name: "Adapter (BSD)", family: "C"),
        adapter_def(id: "b", name: "Other (glibc)", family: "C"),
      ]
      expect(described_class.build_family_range_label(fam)).to eq("BSD → glibc")
    end
  end

  describe ".compute_family_divergence" do
    let(:fam_adapters) do
      [
        adapter_def(id: "lib-a", name: "A", family: "Ruby"),
        adapter_def(id: "lib-b", name: "B", family: "Ruby"),
        adapter_def(id: "lib-c", name: "C", family: "Ruby"),
      ]
    end

    it "reports stability='stable' when all versions agree on every test" do
      requirements = [{
        id: "req:stable",
        tests: { "lib-a" => { "parse_general" => { details: [
          { test_id: "t1", result: "pass" } ] } },
                 "lib-b" => { "parse_general" => { details: [
          { test_id: "t1", result: "pass" } ] } },
                 "lib-c" => { "parse_general" => { details: [
          { test_id: "t1", result: "pass" } ] } } },
      }]
      result = described_class.compute_family_divergence(fam_adapters, requirements)
      expect(result[:stability]).to eq("stable")
      expect(result[:delta_count]).to eq(0)
      expect(result[:divergent_tests]).to eq([])
      expect(result[:per_version_delta]).to eq({ "lib-a" => 0, "lib-b" => 0, "lib-c" => 0 })
    end

    it "records the divergent test and attributes deltas to minority voters" do
      requirements = [{
        id: "req:divergent",
        tests: { "lib-a" => { "parse_general" => { details: [
          { test_id: "t1", result: "pass" } ] } },
                 "lib-b" => { "parse_general" => { details: [
          { test_id: "t1", result: "pass" } ] } },
                 "lib-c" => { "parse_general" => { details: [
          { test_id: "t1", result: "fail" } ] } } },
      }]
      result = described_class.compute_family_divergence(fam_adapters, requirements)
      expect(result[:stability]).to eq("minor")
      expect(result[:delta_count]).to eq(1)
      divergent = result[:divergent_tests].first
      expect(divergent[:test_id]).to eq("t1")
      expect(divergent[:req_id]).to eq("req:divergent")
      expect(divergent[:results]).to eq({ "lib-a" => "pass", "lib-b" => "pass", "lib-c" => "fail" })
      expect(result[:per_version_delta]["lib-c"]).to eq(1)
      expect(result[:per_version_delta]["lib-a"]).to eq(0)
    end

    it "reports 'divergent' stability when more than 5 deltas exist" do
      requirements = (1..6).map do |i|
        { id: "req:r#{i}",
          tests: { "lib-a" => { "parse_general" => { details: [
            { test_id: "t#{i}", result: "pass" } ] } },
                   "lib-b" => { "parse_general" => { details: [
            { test_id: "t#{i}", result: "fail" } ] } } } }
      end
      result = described_class.compute_family_divergence(
        [adapter_def(id: "lib-a", name: "A", family: "Ruby"),
         adapter_def(id: "lib-b", name: "B", family: "Ruby")], requirements
      )
      expect(result[:stability]).to eq("divergent")
      expect(result[:delta_count]).to eq(6)
    end

    it "skips requirements with no per-adapter test data" do
      requirements = [{ id: "req:empty", tests: {} }]
      result = described_class.compute_family_divergence(fam_adapters, requirements)
      expect(result[:delta_count]).to eq(0)
      expect(result[:stability]).to eq("stable")
    end

    it "treats nil result values as 'unknown' in the divergent record" do
      requirements = [{
        id: "req:nil-result",
        tests: { "lib-a" => { "parse_general" => { details: [
          { test_id: "t1", result: nil } ] } },
                 "lib-b" => { "parse_general" => { details: [
          { test_id: "t1", result: "pass" } ] } } },
      }]
      result = described_class.compute_family_divergence(
        [adapter_def(id: "lib-a", name: "A", family: "Ruby"),
         adapter_def(id: "lib-b", name: "B", family: "Ruby")], requirements
      )
      expect(result[:delta_count]).to eq(1)
      expect(result[:divergent_tests].first[:results]["lib-a"]).to eq("unknown")
    end
  end

  describe ".build (full slice assembly)" do
    it "produces one slice per family with range_label and stability metadata" do
      adapters = [
        adapter_def(id: "ruby-30", name: "Ruby 3.0 Date", family: "Ruby", logo: "/logos/ruby.svg", language: "ruby"),
        adapter_def(id: "ruby-32", name: "Ruby 3.2 Date", family: "Ruby", logo: "/logos/ruby.svg", language: "ruby"),
        adapter_def(id: "rust-1",  name: "Rust chrono",   family: "Rust", logo: "/logos/rust.svg", language: "rust"),
      ]
      requirements = []
      result = described_class.build(adapters, requirements)
      ruby = result.find { |f| f[:family] == "Ruby" }
      expect(ruby[:version_count]).to eq(2)
      expect(ruby[:range_label]).to eq("3.0 → 3.2")
      expect(ruby[:stability]).to eq("stable")

      rust = result.find { |f| f[:family] == "Rust" }
      expect(rust[:version_count]).to eq(1)
      expect(rust[:stability]).to eq("single")
      expect(rust[:range_label]).to eq("Rust chrono")
    end
  end
end
