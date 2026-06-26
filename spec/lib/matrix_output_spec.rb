# frozen_string_literal: true

require "tmpdir"
require_relative "../../lib/test_suite/matrix_output"

RSpec.describe MatrixOutput do
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

  describe ".project_summary and .project_detail (round-trip)" do
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

    it "project_summary omits per-requirement details and profile traceability" do
      summary = described_class.project_summary(full_data)
      req_a = summary[:requirements].find { |r| r[:id] == "req:a" }
      expect(req_a[:tests]["lib-a"]["parse_general"]).not_to have_key(:details)
      profile = summary[:profiles].find { |p| p[:id] == "profile:x" }
      expect(profile).not_to have_key(:traceability)
    end

    it "project_detail produces the complementary details payload" do
      details = described_class.project_detail(full_data)
      req_a = details[:requirements].find { |r| r[:id] == "req:a" }
      expect(req_a[:tests]["lib-a"]["parse_general"]).to have_key(:details)
      profile = details[:profiles].find { |p| p[:id] == "profile:x" }
      expect(profile).to have_key(:traceability)
    end

    it "project_detail returns [] for requirements with no per-library details" do
      sparse = {
        generated_at: "2026-06-25T00:00:00Z",
        libraries: [], family_stats: [], categories: [],
        profiles: [],
        requirements: [{ id: "req:empty", tests: {} }],
      }
      details = described_class.project_detail(sparse)
      expect(details[:requirements]).to eq([])
    end
  end

  describe ".write_summary and .write_detail" do
    let(:full_data) do
      {
        generated_at: "2026-06-25T00:00:00Z",
        libraries: [{ id: "lib-a" }],
        family_stats: [],
        categories: [],
        profiles: [{ id: "profile:x", traceability: [{ id: "cc:a", requirements: [] }] }],
        requirements: [{
          id: "req:a", category: "Cat A", statement: "do x",
          tests: { "lib-a" => {
            "parse_general" => { status: "pass", pass: 1, total: 1,
                                 details: [{ test_id: "t1", result: "pass", notes: nil }] },
          } },
        }],
      }
    end

    it "writes the summary projection with nils stripped" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "summary.json")
        described_class.write_summary(full_data, path)
        parsed = JSON.parse(File.read(path))
        expect(parsed["generated_at"]).to eq("2026-06-25T00:00:00Z")
        req_a = parsed["requirements"].find { |r| r["id"] == "req:a" }
        expect(req_a["tests"]["lib-a"]["parse_general"]).not_to have_key("details")
        profile = parsed["profiles"].find { |p| p["id"] == "profile:x" }
        expect(profile).not_to have_key("traceability")
      end
    end

    it "writes the detail projection with nils stripped" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "detail.json")
        described_class.write_detail(full_data, path)
        parsed = JSON.parse(File.read(path))
        req_a = parsed["requirements"].find { |r| r["id"] == "req:a" }
        detail = req_a["tests"]["lib-a"]["parse_general"]["details"].first
        expect(detail).not_to have_key("notes")
        profile = parsed["profiles"].find { |p| p["id"] == "profile:x" }
        expect(profile).to have_key("traceability")
      end
    end
  end
end
