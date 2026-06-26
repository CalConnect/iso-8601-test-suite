# frozen_string_literal: true

require "tempfile"
require_relative "../../lib/test_suite/load_result"
require_relative "../../lib/test_suite/yaml_store"

RSpec.describe YamlStore do
  subject(:store) { described_class.new }

  describe "#load" do
    it "returns LoadResult.success for a valid file" do
      with_temp_file("id: test\nname: hello") do |path|
        result = store.load(path)
        expect(result).to be_success
        expect(result.data).to eq({ "id" => "test", "name" => "hello" })
      end
    end

    it "returns LoadResult.failure for an invalid file" do
      with_temp_file(":\n  bad: [yaml: invalid") do |path|
        result = store.load(path)
        expect(result).to be_failure
        expect(result.error_message).to be_a(String)
      end
    end

    it "caches the result" do
      with_temp_file("key: value") do |path|
        result1 = store.load(path)
        result2 = store.load(path)
        expect(result1).to equal(result2)
      end
    end

    it "handles YAML with symbol-permitted classes" do
      with_temp_file("key: !ruby/symbol hello") do |path|
        result = store.load(path)
        expect(result).to be_success
        expect(result.data["key"]).to eq(:hello)
      end
    end
  end

  describe "#files_in" do
    it "returns sorted unique files matching globs" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "a.yaml"), "")
        File.write(File.join(dir, "b.yaml"), "")

        results = store.files_in(File.join(dir, "*.yaml"))
        expect(results.length).to eq(2)
        expect(results).to eq(results.sort)
      end
    end
  end
end
