# frozen_string_literal: true

require_relative "../../lib/test_suite/schema_registry"

RSpec.describe SchemaRegistry do
  describe ".schema_for" do
    it "maps the suite manifest to schema/suite.yaml" do
      expect(described_class.schema_for("suite.yaml")).to eq("schema/suite.yaml")
    end

    it "maps Part 1 requirements files to the requirements-class schema" do
      expect(described_class.schema_for("requirements/8601-1/fundamentals.yaml"))
        .to eq("schema/requirements-class.yaml")
    end

    it "maps Part 2 requirements files to the requirements-class schema" do
      expect(described_class.schema_for("requirements/8601-2/arithmetic.yaml"))
        .to eq("schema/requirements-class.yaml")
    end

    it "maps conformance class test files to the conformance-class schema" do
      expect(described_class.schema_for("tests/8601-1/calendar-date.yaml"))
        .to eq("schema/conformance-class.yaml")
    end

    it "maps profile files to the profile schema" do
      expect(described_class.schema_for("profiles/rfc-3339.yaml"))
        .to eq("schema/profile.yaml")
    end

    it "maps result files to the conformance-result schema" do
      expect(described_class.schema_for("results/ruby-3-date.yaml"))
        .to eq("schema/conformance-result.yaml")
    end

    it "TEMPLATE.yaml inherits its directory's schema" do
      expect(described_class.schema_for("profiles/TEMPLATE.yaml"))
        .to eq("schema/profile.yaml")
    end

    it "returns nil for paths outside the data directories" do
      expect(described_class.schema_for("config/adapters.yaml")).to be_nil
      expect(described_class.schema_for("schema/suite.yaml")).to be_nil
      expect(described_class.schema_for("README.md")).to be_nil
    end
  end

  describe "MAPPING coverage" do
    it "every registered schema path exists under schema/" do
      repo_root = File.expand_path("../..", __dir__)
      described_class::MAPPING.each do |_matcher, schema_rel|
        path = File.join(repo_root, schema_rel)
        expect(File.exist?(path)).to be(true),
          "expected registered schema path '#{schema_rel}' to exist"
      end
    end
  end
end
