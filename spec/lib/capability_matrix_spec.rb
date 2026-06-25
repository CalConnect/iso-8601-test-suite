# frozen_string_literal: true

require "tmpdir"
require_relative "../../lib/test_suite/capability_matrix"

RSpec.describe CapabilityMatrix do
  describe "ADAPTER_DEFS" do
    it "is a non-empty frozen array of hashes" do
      expect(described_class::ADAPTER_DEFS).to be_an(Array)
      expect(described_class::ADAPTER_DEFS).to be_frozen
      expect(described_class::ADAPTER_DEFS.length).to be > 10
    end

    it "every entry has the required keys" do
      required = [:id, :name, :family, :logo, :adapter].sort
      described_class::ADAPTER_DEFS.each do |entry|
        missing = required - entry.keys
        expect(missing).to be_empty, "entry #{entry[:id]} missing: #{missing.inspect}"
      end
    end

    it "every id is unique" do
      ids = described_class::ADAPTER_DEFS.map { |e| e[:id] }
      expect(ids.length).to eq(ids.uniq.length)
    end

    it "every id matches the lowercase CURIE-like pattern" do
      described_class::ADAPTER_DEFS.each do |entry|
        expect(entry[:id]).to match(/\A[a-z][a-z0-9-]*\z/)
      end
    end

    it "every family is a non-empty string" do
      described_class::ADAPTER_DEFS.each do |entry|
        expect(entry[:family]).to be_a(String)
        expect(entry[:family]).not_to be_empty
      end
    end

    it "every logo references a known static asset path" do
      described_class::ADAPTER_DEFS.each do |entry|
        expect(entry[:logo]).to match(%r{\A/logos/[a-z0-9-]+\.svg\z})
      end
    end

    it "every adapter starts with exec: or is a named adapter id" do
      described_class::ADAPTER_DEFS.each do |entry|
        adapter = entry[:adapter]
        expect(adapter).to match(/\A(exec:|[a-z][a-z0-9-]*\z)/)
      end
    end

    it "families partition the adapter set (every entry belongs to a family)" do
      families = described_class::ADAPTER_DEFS.group_by { |e| e[:family] }
      expect(families.length).to be > 1
      families.each do |family, members|
        expect(members.length).to be >= 1
        logos = members.map { |m| m[:logo] }.uniq
        expect(logos.length).to eq(1),
          "family '#{family}' has mixed logos: #{logos.inspect}"
      end
    end
  end

  describe "TEST_TYPE_TO_CAPABILITY" do
    it "is a frozen hash mapping every declared test type" do
      expect(described_class::TEST_TYPE_TO_CAPABILITY).to be_a(Hash)
      expect(described_class::TEST_TYPE_TO_CAPABILITY).to be_frozen
    end

    it "validity and parsing both map to parse_general" do
      map = described_class::TEST_TYPE_TO_CAPABILITY
      expect(map["validity"]).to eq("parse_general")
      expect(map["parsing"]).to eq("parse_general")
    end

    it "generation maps to construct" do
      expect(described_class::TEST_TYPE_TO_CAPABILITY["generation"]).to eq("construct")
    end

    it "arithmetic maps to arithmetic" do
      expect(described_class::TEST_TYPE_TO_CAPABILITY["arithmetic"]).to eq("arithmetic")
    end
  end

  describe "PROFILE_ORG_LOGOS" do
    it "is a frozen hash" do
      expect(described_class::PROFILE_ORG_LOGOS).to be_a(Hash)
      expect(described_class::PROFILE_ORG_LOGOS).to be_frozen
    end

    it "every key is a profile CURIE" do
      described_class::PROFILE_ORG_LOGOS.each_key do |key|
        expect(key).to match(/\Aprofile:[a-z0-9-]+\z/)
      end
    end

    it "every value is a /logos/ svg path" do
      described_class::PROFILE_ORG_LOGOS.each_value do |logo|
        expect(logo).to match(%r{\A/logos/[a-z0-9-]+\.svg\z})
      end
    end
  end

  describe ".clean_nils" do
    it "strips nil values from nested hashes" do
      input = { a: 1, b: nil, c: { d: nil, e: 2 } }
      result = described_class.clean_nils(input)
      expect(result).to eq({ a: 1, c: { e: 2 } })
    end

    it "recurses through arrays" do
      input = { list: [1, nil, { x: nil, y: 3 }] }
      result = described_class.clean_nils(input)
      expect(result).to eq({ list: [1, nil, { y: 3 }] })
    end

    it "leaves primitives unchanged" do
      expect(described_class.clean_nils(42)).to eq(42)
      expect(described_class.clean_nils("hi")).to eq("hi")
      expect(described_class.clean_nils(nil)).to be_nil
    end
  end

  describe ".strip_test_details" do
    it "drops the :details key and keeps status/pass/total" do
      tests = {
        "lib-a" => {
          "parse_general" => { status: "pass", pass: 5, total: 5,
                               details: [{ test_id: "t1", result: "pass" }] },
        },
      }
      result = described_class.strip_test_details(tests)
      expect(result["lib-a"]["parse_general"]).to eq({ status: "pass", pass: 5, total: 5 })
      expect(result["lib-a"]["parse_general"]).not_to have_key(:details)
    end
  end

  describe ".write_compact" do
    it "writes clean_nils-applied JSON to the given path, creating dirs" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "nested", "out.json")
        data = { a: 1, b: nil }
        described_class.write_compact(data, path)
        contents = File.read(path)
        expect(JSON.parse(contents)).to eq({ "a" => 1 })
      end
    end
  end

  describe ".strip_details and .extract_details (round-trip)" do
    let(:full_data) do
      {
        generated_at: "2026-06-25T00:00:00Z",
        libraries: [{ id: "lib-a" }],
        family_stats: [{ family: "Fam A" }],
        categories: [{ name: "Cat A", count: 1 }],
        profiles: [{ id: "profile:x", name: "X",
                     traceability: [{ id: "cc:a", requirements: [] }] }],
        requirements: [
          { id: "req:a", category: "Cat A", statement: "do x",
            tests: { "lib-a" => {
              "parse_general" => { status: "pass", pass: 1, total: 1,
                                   details: [{ test_id: "t1", result: "pass" }] },
            } } },
        ],
      }
    end

    it "strip_details omits per-requirement details and profile traceability" do
      summary = described_class.strip_details(full_data)
      req_a = summary[:requirements].find { |r| r[:id] == "req:a" }
      expect(req_a[:tests]["lib-a"]["parse_general"]).not_to have_key(:details)
      profile = summary[:profiles].find { |p| p[:id] == "profile:x" }
      expect(profile).not_to have_key(:traceability)
    end

    it "extract_details produces the complementary details payload" do
      details = described_class.extract_details(full_data)
      req_a = details[:requirements].find { |r| r[:id] == "req:a" }
      expect(req_a[:tests]["lib-a"]["parse_general"]).to have_key(:details)
      profile = details[:profiles].find { |p| p[:id] == "profile:x" }
      expect(profile).to have_key(:traceability)
    end

    it "extract_details returns [] for requirements with no per-library details" do
      sparse = {
        generated_at: "2026-06-25T00:00:00Z",
        libraries: [], family_stats: [], categories: [],
        profiles: [],
        requirements: [{ id: "req:empty", tests: {} }],
      }
      details = described_class.extract_details(sparse)
      expect(details[:requirements]).to eq([])
    end
  end
end
