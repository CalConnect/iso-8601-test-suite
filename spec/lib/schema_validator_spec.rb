# frozen_string_literal: true

require "tempfile"
require_relative "../../lib/test_suite/schema_validator"
require_relative "../../lib/test_suite/stats"
require_relative "../../lib/test_suite/yaml_store"

RSpec.describe SchemaValidator do
  let(:stats) { Stats.new }
  let(:store) { YamlStore.new }
  subject(:validator) { described_class.new(stats, store) }

  def create_schema_and_data(schema_content, data_content)
    dir = Dir.mktmpdir
    schema_path = File.join(dir, "schema.yaml")
    data_path = File.join(dir, "data.yaml")
    File.write(schema_path, schema_content)
    File.write(data_path, "# yaml-language-server: $schema=schema.yaml\n#{data_content}")
    [dir, schema_path, data_path]
  end

  describe "#validate_file" do
    it "warns when no $schema reference found" do
      with_temp_file("key: value") do |path|
        validator.validate_file(path)
        expect(stats.warnings.length).to eq(1)
        expect(stats.warnings.first[:msg]).to include("No $schema")
      end
    end

    it "reports an error for missing required field" do
      dir, _schema, data = create_schema_and_data(
        "type: object\nrequired:\n  - id\nproperties:\n  id:\n    type: string",
        "name: test"
      )
      validator.validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("missing required field 'id'")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "passes for a valid file" do
      dir, _schema, data = create_schema_and_data(
        "type: object\nrequired:\n  - id\nproperties:\n  id:\n    type: string",
        "id: test"
      )
      validator.validate_file(data)
      expect(stats.errors.length).to eq(0)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "reports type mismatch" do
      dir, _schema, data = create_schema_and_data(
        "type: object\nproperties:\n  count:\n    type: integer",
        "count: hello"
      )
      validator.validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("expected type integer")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "validates pattern constraints" do
      dir, _schema, data = create_schema_and_data(
        "type: string\npattern: \"^req:[a-z]+$\"",
        "req:validname"
      )
      validator.validate_file(data)
      expect(stats.errors.length).to eq(0)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "reports pattern mismatch" do
      dir, _schema, data = create_schema_and_data(
        "type: string\npattern: \"^req:[a-z]+$\"",
        "INVALID"
      )
      validator.validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("does not match pattern")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "validates enum values" do
      dir, _schema, data = create_schema_and_data(
        "type: string\nenum:\n  - basic\n  - extended",
        "basic"
      )
      validator.validate_file(data)
      expect(stats.errors.length).to eq(0)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "reports value not in enum" do
      dir, _schema, data = create_schema_and_data(
        "type: string\nenum:\n  - basic\n  - extended",
        "invalid"
      )
      validator.validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("not in enum")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "validates array items" do
      dir, _schema, data = create_schema_and_data(
        "type: array\nitems:\n  type: string",
        "- hello\n- world"
      )
      validator.validate_file(data)
      expect(stats.errors.length).to eq(0)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "reports array item type mismatch" do
      dir, _schema, data = create_schema_and_data(
        "type: array\nitems:\n  type: string",
        "- hello\n- 42"
      )
      validator.validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("expected type string")
    ensure
      FileUtils.remove_entry(dir)
    end
  end
end
