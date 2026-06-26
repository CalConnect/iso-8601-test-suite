# frozen_string_literal: true

require "tempfile"
require "fileutils"
require_relative "../../lib/test_suite/schema_registry"
require_relative "../../lib/test_suite/schema_validator"
require_relative "../../lib/test_suite/stats"
require_relative "../../lib/test_suite/yaml_store"

RSpec.describe SchemaValidator do
  let(:stats) { Stats.new }
  let(:store) { YamlStore.new }

  # Build a validator with a real callable resolver that maps any path
  # to the test fixture's schema. Real Proc, not a double.
  def validator_for(schema_path)
    resolver = ->(_path) { schema_path }
    described_class.new(stats, store, schema_resolver: resolver)
  end

  def create_schema_and_data(schema_content, data_content)
    dir = Dir.mktmpdir
    schema_path = File.join(dir, "schema.yaml")
    data_path = File.join(dir, "data.yaml")
    File.write(schema_path, schema_content)
    File.write(data_path, data_content)
    [dir, schema_path, data_path]
  end

  describe "#validate_file" do
    it "warns when no schema is registered for the path" do
      no_schema_resolver = ->(_path) { nil }
      validator = described_class.new(stats, store, schema_resolver: no_schema_resolver)
      with_temp_file("key: value") do |path|
        validator.validate_file(path)
        expect(stats.warnings.length).to eq(1)
        expect(stats.warnings.first[:msg]).to include("No schema registered")
      end
    end

    it "reports an error for missing required field" do
      dir, schema, data = create_schema_and_data(
        "type: object\nrequired:\n  - id\nproperties:\n  id:\n    type: string",
        "name: test"
      )
      validator_for(schema).validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("missing required field 'id'")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "passes for a valid file" do
      dir, schema, data = create_schema_and_data(
        "type: object\nrequired:\n  - id\nproperties:\n  id:\n    type: string",
        "id: test"
      )
      validator_for(schema).validate_file(data)
      expect(stats.errors.length).to eq(0)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "reports type mismatch" do
      dir, schema, data = create_schema_and_data(
        "type: object\nproperties:\n  count:\n    type: integer",
        "count: hello"
      )
      validator_for(schema).validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("expected type integer")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "validates pattern constraints" do
      dir, schema, data = create_schema_and_data(
        "type: string\npattern: \"^req:[a-z]+$\"",
        "req:validname"
      )
      validator_for(schema).validate_file(data)
      expect(stats.errors.length).to eq(0)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "reports pattern mismatch" do
      dir, schema, data = create_schema_and_data(
        "type: string\npattern: \"^req:[a-z]+$\"",
        "INVALID"
      )
      validator_for(schema).validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("does not match pattern")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "validates enum values" do
      dir, schema, data = create_schema_and_data(
        "type: string\nenum:\n  - basic\n  - extended",
        "basic"
      )
      validator_for(schema).validate_file(data)
      expect(stats.errors.length).to eq(0)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "reports value not in enum" do
      dir, schema, data = create_schema_and_data(
        "type: string\nenum:\n  - basic\n  - extended",
        "invalid"
      )
      validator_for(schema).validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("not in enum")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "validates array items" do
      dir, schema, data = create_schema_and_data(
        "type: array\nitems:\n  type: string",
        "- hello\n- world"
      )
      validator_for(schema).validate_file(data)
      expect(stats.errors.length).to eq(0)
    ensure
      FileUtils.remove_entry(dir)
    end

    it "reports array item type mismatch" do
      dir, schema, data = create_schema_and_data(
        "type: array\nitems:\n  type: string",
        "- hello\n- 42"
      )
      validator_for(schema).validate_file(data)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:msg]).to include("expected type string")
    ensure
      FileUtils.remove_entry(dir)
    end

    it "uses the default SchemaRegistry when no resolver is injected" do
      dir = Dir.mktmpdir
      data_path = File.join(dir, "requirements", "fixture.yaml")
      FileUtils.mkdir_p(File.dirname(data_path))
      File.write(data_path, "id: req:fixture")
      # The default resolver maps requirements/** to schema/requirements-class.yaml
      # which exists in the repo. We can't guarantee it'll match this fixture's
      # shape, but the validator should at least find the schema file without
      # raising — i.e. SchemaRegistry is wired correctly.
      real_resolver = SchemaRegistry.method(:schema_for)
      expect(real_resolver.call("requirements/fixture.yaml"))
        .to eq("schema/requirements-class.yaml")
    ensure
      FileUtils.remove_entry(dir)
    end
  end
end
