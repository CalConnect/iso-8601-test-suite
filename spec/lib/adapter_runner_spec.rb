# frozen_string_literal: true

require "set"
require_relative "../../lib/test_suite/adapter_runner"
require_relative "../../lib/test_suite/test"

# Minimal Struct-based adapter that records calls and returns canned
# results. Per repo conventions: real instances over doubles.
FakeAdapter = Struct.new(:version, :language, :next_results) do
  def qualification_notes = []
end

FakeTestTypeHandlers = Module.new do
  module_function

  attr_accessor :adapter_map

  def run(adapter, test)
    adapter.next_results.shift || { "result" => "pass" }
  end
end

RSpec.describe AdapterRunner do
  let(:fake_index) do
    Class.new do
      def initialize(mapping)
        @mapping = mapping
      end
      def bare_id(id) = id
      def class_for_test(test_id) = @mapping[test_id]
    end.new({ "conf-test:t-001" => "conf-class:declared", "conf-test:t-002" => "conf-class:other" })
  end

  let(:adapter) { FakeAdapter.new("1.0", "ruby", [{ "result" => "pass" }, { "result" => "fail" }]) }

  it "runs tests through TestTypeHandlers when no declaration set is provided" do
    runner = described_class.new(adapter, declared_bare: [], index: fake_index)
    stub_const("TestTypeHandlers", FakeTestTypeHandlers)
    results = runner.call([
      Test.new("id" => "conf-test:t-001", "test_type" => "validity"),
      Test.new("id" => "conf-test:t-002", "test_type" => "validity"),
    ])
    expect(results.map { |r| r["result"] }).to eq(["pass", "fail"])
  end

  it "returns 'not-supported' for tests whose class is not in the declared set" do
    runner = described_class.new(
      adapter,
      declared_bare: ["conf-class:declared"].to_set,
      index: fake_index,
    )
    stub_const("TestTypeHandlers", FakeTestTypeHandlers)
    results = runner.call([
      Test.new("id" => "conf-test:t-001", "test_type" => "validity"),
      Test.new("id" => "conf-test:t-002", "test_type" => "validity"),
    ])
    expect(results.first["result"]).to eq("pass")
    expect(results.last["result"]).to eq("not-supported")
    expect(results.last["notes"]).to eq("Conformance class not declared")
  end

  it "wraps adapter exceptions into error results" do
    breaking = FakeAdapter.new("1.0", "ruby", nil)
    breaking.define_singleton_method(:version) { raise "boom" }
    stub_const("TestTypeHandlers", Module.new do
      module_function
      def run(adapter, test) = raise(StandardError, "adapter blew up")
    end)
    runner = described_class.new(breaking, declared_bare: [], index: fake_index)
    result = runner.call([Test.new("id" => "conf-test:t-001", "test_type" => "validity")]).first
    expect(result["result"]).to eq("error")
    expect(result["notes"]).to eq("adapter blew up")
  end

  it "memoizes results so the same test instance is computed once across calls" do
    call_count = 0
    counting_handlers = Module.new do
      module_function
      define_method(:run) do |_adapter, _test|
        call_count += 1
        { "result" => "pass" }
      end
    end
    stub_const("TestTypeHandlers", counting_handlers)
    test = Test.new("id" => "conf-test:t-001", "test_type" => "validity")
    runner = described_class.new(adapter, declared_bare: [], index: fake_index)

    first = runner.call([test])
    second = runner.call([test])

    expect(call_count).to eq(1)
    expect(second.first).to be(first.first)
  end
end
