# frozen_string_literal: true

require "set"
require_relative "../../lib/test_suite/matrix_context"
require_relative "../../lib/test_suite/adapter_runner"

RSpec.describe MatrixContext do
  let(:fake_index) do
    Class.new do
      def bare_id(id) = id.sub(/^8601-1:/, "")
      def class_for_test(_tid) = "conf-class:x"
    end.new
  end

  let(:adapter_a) { { id: "lib-a", adapter: Struct.new(:version, :language).new("1.0", "ruby") } }

  let(:ctx) do
    described_class.new(
      store: nil, index: fake_index,
      adapters: [adapter_a],
      declared_classes: { "lib-a" => ["8601-1:conf-class:x", "conf-class:y"] },
      declared_profiles: { "lib-a" => ["profile:foo"] },
      req_index: {}, req_tests: {}, class_tests: {},
      profile_tests: {}, profile_req_map: {}, test_reqs: {},
    )
  end

  it "exposes all derived collections as readers" do
    expect(ctx.adapters).to eq([adapter_a])
    expect(ctx.declared_classes).to eq({ "lib-a" => ["8601-1:conf-class:x", "conf-class:y"] })
    expect(ctx.declared_profiles).to eq({ "lib-a" => ["profile:foo"] })
    expect(ctx.declared_profiles_for("lib-a")).to eq(["profile:foo"])
  end

  it "declared_bare_for strips part prefixes from declared class IDs" do
    expect(ctx.declared_bare_for("lib-a")).to eq(["conf-class:x", "conf-class:y"])
  end

  it "declared_bare_for returns [] when the adapter has no entry" do
    expect(ctx.declared_bare_for("unknown-lib")).to eq([])
  end

  it "runner_for returns a memoized AdapterRunner wired with the adapter and declaration set" do
    runner = ctx.runner_for("lib-a")
    expect(runner).to be_an(AdapterRunner)
    expect(ctx.runner_for("lib-a")).to be(runner)
  end
end
