# frozen_string_literal: true

require "tempfile"

REPO_ROOT = File.expand_path(File.join(__dir__, "..", ".."))

require_relative "../../lib/test_suite/load_result"
require_relative "../../lib/test_suite/stats"
require_relative "../../lib/test_suite/yaml_store"
require_relative "../../lib/test_suite/suite_validations"
require_relative "../../lib/test_suite/suite_index"

# Minimal real object that quacks like SuiteIndex for the parts of its API
# that SuiteValidations.check_test_req_references touches. Using a Struct
# (not a double) keeps the test honest about the contract.
FakeReqRefIndex = Struct.new(:test_reqs, :file_for_test_map, :all_req_ids_list) do
  def file_for_test(tid)
    file_for_test_map[tid]
  end

  def all_req_ids
    all_req_ids_list
  end
end

RSpec.describe SuiteValidations do
  let(:stats) { Stats.new }

  describe ".check_urn_format" do
    it "accepts well-formed RFC 5141 URNs" do
      source_map = {
        "requirements/8601-1/fundamentals.yaml" => [
          "urn:iso:std:iso:8601:-1:ed-1:en:clause:4.2.1"
        ]
      }
      checked, bad = described_class.check_urn_format(source_map, stats)
      expect(checked).to eq(1)
      expect(bad).to eq(0)
      expect(stats).to be_ok
    end

    it "accepts URNs without clause" do
      source_map = { "x.yaml" => ["urn:iso:std:iso:8601:-2:ed-1:en"] }
      _checked, bad = described_class.check_urn_format(source_map, stats)
      expect(bad).to eq(0)
    end

    it "accepts HTTPS URLs as alternatives" do
      source_map = { "x.yaml" => ["https://example.org/ref"] }
      _checked, bad = described_class.check_urn_format(source_map, stats)
      expect(bad).to eq(0)
    end

    it "rejects malformed URNs" do
      source_map = { "requirements/x.yaml" => ["iso:8601:bad"] }
      _checked, bad = described_class.check_urn_format(source_map, stats)
      expect(bad).to eq(1)
      expect(stats.errors.length).to eq(1)
    end

    it "skips files outside requirements/tests/profiles" do
      source_map = { "results/x.yaml" => ["not-a-urn"] }
      checked, bad = described_class.check_urn_format(source_map, stats)
      expect(checked).to eq(0)
      expect(bad).to eq(0)
    end
  end

  describe ".check_test_id_naming" do
    it "accepts IDs following conf-test:{prefix}-{type}-{NNN}" do
      test_ids = { "conf-test:cal-date-parse-001" => "tests/8601-1/calendar-date.yaml" }
      checked, bad = described_class.check_test_id_naming(test_ids, stats)
      expect(checked).to eq(1)
      expect(bad).to eq(0)
    end

    it "flags IDs that omit the numeric suffix" do
      test_ids = { "conf-test:cal-date-parse" => "x.yaml" }
      _checked, bad = described_class.check_test_id_naming(test_ids, stats)
      expect(bad).to eq(1)
    end

    it "flags IDs with uppercase characters" do
      test_ids = { "conf-test:CalDate-parse-001" => "x.yaml" }
      _checked, bad = described_class.check_test_id_naming(test_ids, stats)
      expect(bad).to eq(1)
    end
  end

  describe ".check_test_req_references" do
    it "counts every (test, requirement) pair and reports zero bad when all resolve" do
      index = FakeReqRefIndex.new(
        { "conf-test:foo-parse-001" => ["req:a", "req:b"] },
        { "conf-test:foo-parse-001" => "tests/x.yaml" },
        ["req:a", "req:b"]
      )
      checked, bad = described_class.check_test_req_references(index, stats)
      expect(checked).to eq(2)
      expect(bad).to eq(0)
      expect(stats).to be_ok
    end

    it "records an error per dangling requirement reference" do
      index = FakeReqRefIndex.new(
        { "conf-test:foo-parse-001" => ["req:known", "req:missing"] },
        { "conf-test:foo-parse-001" => "tests/x.yaml" },
        ["req:known"]
      )
      checked, bad = described_class.check_test_req_references(index, stats)
      expect(checked).to eq(2)
      expect(bad).to eq(1)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:path]).to eq("tests/x.yaml")
      expect(stats.errors.first[:msg]).to include("conf-test:foo-parse-001")
      expect(stats.errors.first[:msg]).to include("req:missing")
    end

    it "falls back to the 'tests' path label when file_for_test is unknown" do
      index = FakeReqRefIndex.new(
        { "conf-test:orphan-001" => ["req:missing"] },
        {},
        ["req:known"]
      )
      _checked, bad = described_class.check_test_req_references(index, stats)
      expect(bad).to eq(1)
      expect(stats.errors.first[:path]).to eq("tests")
    end

    it "handles a test with no requirements gracefully" do
      index = FakeReqRefIndex.new(
        { "conf-test:empty-001" => [] },
        { "conf-test:empty-001" => "tests/x.yaml" },
        []
      )
      checked, bad = described_class.check_test_req_references(index, stats)
      expect(checked).to eq(0)
      expect(bad).to eq(0)
    end

    it "passes against the real suite data (every test ref resolves)" do
      real_index = SuiteIndex.new(YamlStore.new)
      real_index.load_all
      _checked, bad = described_class.check_test_req_references(real_index, stats)
      expect(bad).to eq(0)
      expect(stats).to be_ok
    end
  end
end
