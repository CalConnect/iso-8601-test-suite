# frozen_string_literal: true

require "tempfile"
require "tmpdir"

REPO_ROOT = File.expand_path(File.join(__dir__, "..", ".."))

require_relative "../../lib/test_suite/load_result"
require_relative "../../lib/test_suite/stats"
require_relative "../../lib/test_suite/yaml_store"
require_relative "../../lib/test_suite/requirement"
require_relative "../../lib/test_suite/suite_validations"
require_relative "../../lib/test_suite/suite_index"

# Minimal real objects that quack like SuiteIndex for the parts of its API
# that SuiteValidations touches. Using Structs (not doubles) keeps tests
# honest about the contract.
FakeReqRefIndex = Struct.new(:test_reqs, :file_for_test_map, :all_req_ids_list) do
  def file_for_test(tid)
    file_for_test_map[tid]
  end

  def all_req_ids
    all_req_ids_list
  end
end

FakeCoverageIndex = Struct.new(:test_reqs, :req_ids_map, :profile_req_ids_map, :all_reqs_list) do
  def req_ids
    req_ids_map || {}
  end

  def profile_req_ids
    profile_req_ids_map || {}
  end

  def all_req_ids
    all_reqs_list
  end
end

FakeProfileIndex = Struct.new(:conf_class_ids_map, :req_ids_map, :profile_req_ids_map, :conf_test_ids_map) do
  def conf_class_ids
    conf_class_ids_map || {}
  end

  def req_ids
    req_ids_map || {}
  end

  def profile_req_ids
    profile_req_ids_map || {}
  end

  def conf_test_ids
    conf_test_ids_map || {}
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

  describe ".check_unreferenced_requirements" do
    it "reports zero unreferenced when every req is referenced by a test" do
      index = FakeCoverageIndex.new(
        { "conf-test:foo-001" => ["req:a", "req:b"] },
        { "req:a" => "requirements/x.yaml" },
        nil,
        ["req:a", "req:b"]
      )
      total, unreferenced = described_class.check_unreferenced_requirements(index, stats)
      expect(total).to eq(2)
      expect(unreferenced).to eq(0)
      expect(stats).to be_ok
    end

    it "warns once per unreferenced requirement, tagged with its source file" do
      index = FakeCoverageIndex.new(
        { "conf-test:foo-001" => ["req:a"] },
        { "req:a" => "requirements/x.yaml", "req:b" => "requirements/y.yaml" },
        nil,
        ["req:a", "req:b"]
      )
      _total, unreferenced = described_class.check_unreferenced_requirements(index, stats)
      expect(unreferenced).to eq(1)
      expect(stats.warnings.length).to eq(1)
      expect(stats.warnings.first[:path]).to eq("requirements/y.yaml")
      expect(stats.warnings.first[:msg]).to include("req:b")
    end

    it "falls back to the profile_req_ids source when the req lives in a profile" do
      index = FakeCoverageIndex.new(
        { "conf-test:foo-001" => ["req:a"] },
        {},
        { "req:b" => "profiles/p.yaml" },
        ["req:a", "req:b"]
      )
      _total, unreferenced = described_class.check_unreferenced_requirements(index, stats)
      expect(unreferenced).to eq(1)
      expect(stats.warnings.first[:path]).to eq("profiles/p.yaml")
    end
  end

  describe ".check_profile_references" do
    let(:fake_index) do
      FakeProfileIndex.new(
        { "conf-class:known" => "tests/x.yaml" },
        { "req:known" => "requirements/x.yaml" },
        {},
        { "conf-test:existing-001" => "tests/x.yaml" }
      )
    end

    def write_profile(dir, data)
      path = File.join(dir, "profiles/test.yaml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, YAML.dump(data))
      path
    end

    it "accepts a profile whose CC refs and test refs all resolve" do
      Dir.mktmpdir do |dir|
        write_profile(dir, {
          "id" => "profile:test",
          "conformance_classes" => ["conf-class:known"],
          "additional_tests" => [
            { "id" => "conf-test:new-001", "requirements" => ["req:known"] }
          ]
        })
        store = YamlStore.new(root: dir)
        checked, errors = described_class.check_profile_references(fake_index, store, stats)
        expect(checked).to eq(1)
        expect(errors).to eq(0)
        expect(stats).to be_ok
      end
    end

    it "records an error for unknown conformance class references" do
      Dir.mktmpdir do |dir|
        write_profile(dir, {
          "id" => "profile:test",
          "conformance_classes" => ["conf-class:missing"]
        })
        store = YamlStore.new(root: dir)
        _checked, errors = described_class.check_profile_references(fake_index, store, stats)
        expect(errors).to eq(1)
        expect(stats.errors.first[:msg]).to include("conf-class:missing")
      end
    end

    it "records an error when an additional test references an undefined requirement" do
      Dir.mktmpdir do |dir|
        write_profile(dir, {
          "id" => "profile:test",
          "additional_tests" => [
            { "id" => "conf-test:new-001", "requirements" => ["req:missing"] }
          ]
        })
        store = YamlStore.new(root: dir)
        _checked, errors = described_class.check_profile_references(fake_index, store, stats)
        expect(errors).to eq(1)
        expect(stats.errors.first[:msg]).to include("req:missing")
      end
    end

    it "records an error for a duplicate test ID claimed by another file" do
      Dir.mktmpdir do |dir|
        write_profile(dir, {
          "id" => "profile:test",
          "additional_tests" => [
            { "id" => "conf-test:existing-001", "requirements" => ["req:known"] }
          ]
        })
        store = YamlStore.new(root: dir)
        _checked, errors = described_class.check_profile_references(fake_index, store, stats)
        expect(errors).to eq(1)
        expect(stats.errors.first[:msg]).to include("duplicate test ID")
      end
    end

    it "skips TEMPLATE.yaml files" do
      Dir.mktmpdir do |dir|
        write_profile(dir, {
          "id" => "profile:template",
          "conformance_classes" => ["conf-class:nonexistent"]
        })
        # Rename to TEMPLATE.yaml so it gets skipped
        File.rename(File.join(dir, "profiles/test.yaml"), File.join(dir, "profiles/TEMPLATE.yaml"))
        store = YamlStore.new(root: dir)
        checked, errors = described_class.check_profile_references(fake_index, store, stats)
        expect(checked).to eq(0)
        expect(errors).to eq(0)
      end
    end
  end

  describe ".check_result_references" do
    let(:fake_index) do
      FakeProfileIndex.new(
        { "conf-class:known" => "tests/x.yaml" },
        {},
        {},
        { "conf-test:known-001" => "tests/x.yaml" }
      )
    end

    def write_result(dir, data)
      path = File.join(dir, "results/test.yaml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, YAML.dump(data))
      path
    end

    it "accepts a result file whose CC and test refs all resolve" do
      Dir.mktmpdir do |dir|
        write_result(dir, {
          "id" => "result:test",
          "conformance_class_results" => [
            { "conformance_class" => "conf-class:known",
              "test_results" => [{ "test" => "conf-test:known-001", "result" => "pass" }] }
          ]
        })
        store = YamlStore.new(root: dir)
        checked, errors = described_class.check_result_references(fake_index, store, stats)
        expect(checked).to eq(1)
        expect(errors).to eq(0)
        expect(stats).to be_ok
      end
    end

    it "records an error for unknown conformance class" do
      Dir.mktmpdir do |dir|
        write_result(dir, {
          "conformance_class_results" => [
            { "conformance_class" => "conf-class:missing" }
          ]
        })
        store = YamlStore.new(root: dir)
        _checked, errors = described_class.check_result_references(fake_index, store, stats)
        expect(errors).to eq(1)
        expect(stats.errors.first[:msg]).to include("conf-class:missing")
      end
    end

    it "records an error for undefined test references" do
      Dir.mktmpdir do |dir|
        write_result(dir, {
          "conformance_class_results" => [
            { "conformance_class" => "conf-class:known",
              "test_results" => [{ "test" => "conf-test:missing-001" }] }
          ]
        })
        store = YamlStore.new(root: dir)
        _checked, errors = described_class.check_result_references(fake_index, store, stats)
        expect(errors).to eq(1)
        expect(stats.errors.first[:msg]).to include("conf-test:missing-001")
      end
    end

    it "checks profile_results test refs too" do
      Dir.mktmpdir do |dir|
        write_result(dir, {
          "profile_results" => [
            { "profile" => "profile:x",
              "test_results" => [{ "test" => "conf-test:missing-001" }] }
          ]
        })
        store = YamlStore.new(root: dir)
        _checked, errors = described_class.check_result_references(fake_index, store, stats)
        expect(errors).to eq(1)
        expect(stats.errors.first[:msg]).to include("conf-test:missing-001")
      end
    end

    it "skips TEMPLATE.yaml files" do
      Dir.mktmpdir do |dir|
        write_result(dir, {
          "conformance_class_results" => [
            { "conformance_class" => "conf-class:missing" }
          ]
        })
        File.rename(File.join(dir, "results/test.yaml"), File.join(dir, "results/TEMPLATE.yaml"))
        store = YamlStore.new(root: dir)
        checked, errors = described_class.check_result_references(fake_index, store, stats)
        expect(checked).to eq(0)
        expect(errors).to eq(0)
      end
    end
  end
end
