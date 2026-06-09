# frozen_string_literal: true

require_relative "../../lib/test_suite/adapter_loader"
require_relative "../../lib/test_suite/exec_adapter"

RSpec.describe AdapterLoader do
  describe ".load" do
    it "loads the ruby-date adapter" do
      adapter = described_class.load("ruby-date")
      expect(adapter).to be_a(RubyDateAdapter)
      expect(adapter.name).to eq("Ruby Date/DateTime/Time")
    end

    it "raises AdapterNotFoundError for missing adapter" do
      expect { described_class.load("nonexistent") }.to raise_error(AdapterNotFoundError)
    end

    it "raises an error for exec: with bad command" do
      expect { described_class.load("exec:nonexistent_command_xyz") }.to raise_error(RuntimeError)
    end
  end

  describe ".list" do
    it "returns available adapter names" do
      list = described_class.list
      expect(list).to include("ruby-date")
      expect(list).not_to include("TEMPLATE")
    end

    it "returns sorted names" do
      expect(described_class.list).to eq(described_class.list.sort)
    end
  end
end
