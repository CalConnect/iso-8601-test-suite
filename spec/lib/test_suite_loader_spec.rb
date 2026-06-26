# frozen_string_literal: true

require_relative "../../lib/test_suite/yaml_store"
require_relative "../../lib/test_suite/suite_index"
require_relative "../../lib/test_suite/test"
require_relative "../../lib/test_suite/profile"
require_relative "../../lib/test_suite/test_suite_loader"

RSpec.describe TestSuiteLoader do
  let(:store) { YamlStore.new }
  let(:index) { SuiteIndex.new(store) }
  subject(:loader) { described_class.new(store, index) }

  describe "#tests_for_class" do
    it "returns tests for a known class" do
      tests = loader.tests_for_class("conf-class:calendar-date")
      expect(tests).to be_an(Array)
      expect(tests.length).to be > 0
      expect(tests.first).to be_a(Test)
      expect(tests.first.id).to start_with("conf-test:")
      expect(tests.first.test_type).to be_a(String)
    end

    it "returns empty array for unknown class" do
      expect(loader.tests_for_class("conf-class:nonexistent")).to eq([])
    end

    it "finds tests by prefixed ID" do
      tests = loader.tests_for_class("8601-1:conf-class:calendar-date")
      expect(tests.length).to be > 0
    end
  end

  describe "#tests_for_profile" do
    it "returns tests for a profile with traceability" do
      profile_id = index.profile_ids.find { |pid|
        profile = index.profiles[pid]
        profile.traceability.any?
      }
      skip "No profiles with traceability" unless profile_id

      tests = loader.tests_for_profile(profile_id)
      expect(tests).to be_an(Array)
      expect(tests.length).to be > 0
    end

    it "returns empty array for unknown profile" do
      expect(loader.tests_for_profile("profile:nonexistent")).to eq([])
    end
  end

  describe "#all_tests" do
    it "returns every indexed test" do
      tests = loader.all_tests
      expect(tests.length).to eq(index.total_test_count)
      expect(tests.map { |t| t.id }.uniq.length).to eq(tests.length)
    end
  end

  describe "#profile_ids" do
    it "returns sorted profile IDs" do
      ids = loader.profile_ids
      expect(ids).to eq(ids.sort)
    end
  end

  describe "#class_ids" do
    it "returns sorted class IDs" do
      ids = loader.class_ids
      expect(ids).to eq(ids.sort)
    end
  end
end
