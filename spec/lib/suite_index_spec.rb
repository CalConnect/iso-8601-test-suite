# frozen_string_literal: true

require_relative "../../lib/test_suite/yaml_store"
require_relative "../../lib/test_suite/profile"
require_relative "../../lib/test_suite/suite_index"

RSpec.describe SuiteIndex do
  let(:store) { YamlStore.new }
  subject(:index) { described_class.new(store) }

  before { index.load_all }

  describe "#load_all" do
    it "indexes requirements from the real data" do
      expect(index.req_ids.keys.length).to be > 0
      expect(index.req_class_ids.keys.length).to be > 0
    end

    it "indexes tests from the real data" do
      expect(index.conf_test_ids.keys.length).to be > 0
      expect(index.conf_class_ids.keys.length).to be > 0
    end

    it "indexes profiles from the real data" do
      expect(index.profile_ids.length).to be > 0
    end

    it "is idempotent" do
      count_before = index.conf_test_ids.length
      index.load_all
      expect(index.conf_test_ids.length).to eq(count_before)
    end
  end

  describe "#bare_id" do
    it "strips part prefix" do
      expect(index.bare_id("8601-1:conf-class:calendar-date")).to eq("conf-class:calendar-date")
    end

    it "returns bare IDs unchanged" do
      expect(index.bare_id("conf-class:calendar-date")).to eq("conf-class:calendar-date")
    end
  end

  describe "#resolve_class" do
    it "finds a class by bare ID" do
      result = index.resolve_class("conf-class:calendar-date")
      expect(result).not_to be_nil
      file, bare = result
      expect(bare).to eq("conf-class:calendar-date")
      expect(file).to include("calendar-date")
    end

    it "finds a class by prefixed ID" do
      result = index.resolve_class("8601-1:conf-class:calendar-date")
      expect(result).not_to be_nil
      expect(result[1]).to eq("conf-class:calendar-date")
    end

    it "returns nil for unknown IDs" do
      expect(index.resolve_class("conf-class:nonexistent")).to be_nil
    end
  end

  describe "#part_for_file" do
    it "detects Part 1 files" do
      expect(index.part_for_file("tests/8601-1/calendar-date.yaml")).to eq("8601-1")
    end

    it "detects Part 2 files" do
      expect(index.part_for_file("tests/8601-2/arithmetic.yaml")).to eq("8601-2")
    end
  end

  describe "#class_for_test" do
    it "returns the conf-class ID for a test" do
      first_test_id = index.conf_test_ids.keys.first
      owner = index.class_for_test(first_test_id)
      expect(owner).to satisfy { |id| id.start_with?("conf-class:") || id.start_with?("profile:") }
    end
  end

  describe "#profile_traceability" do
    it "returns an array for profiles with traceability" do
      profile_with_trace = index.profile_ids.find { |pid|
        profile = index.profiles[pid]
        profile.traceability.any?
      }
      skip "No profiles with traceability" unless profile_with_trace

      result = index.profile_traceability(profile_with_trace)
      expect(result).to be_an(Array)
      expect(result.length).to be > 0
      expect(result.first).to respond_to(:conformance_class)
      expect(result.first).to respond_to(:requirements)
    end

    it "returns empty array for unknown profiles" do
      expect(index.profile_traceability("profile:nonexistent")).to eq([])
    end
  end

  describe "#all_req_ids" do
    it "includes both class and profile requirement IDs" do
      all = index.all_req_ids
      expect(all.length).to eq(index.req_ids.length + index.profile_req_ids.length)
    end
  end
end
