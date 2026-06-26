# frozen_string_literal: true

require_relative "../../lib/test_suite/test_status"

RSpec.describe TestStatus do
  describe ".from_results" do
    it "counts pass / fail / error / not-supported results" do
      results = [
        { "result" => "pass" },
        { "result" => "pass" },
        { "result" => "fail" },
        { "result" => "error" },
        { "result" => "not-supported" },
      ]
      status = described_class.from_results(results)
      expect(status.pass).to eq(2)
      expect(status.fail).to eq(2)
      expect(status.not_supported).to eq(1)
      expect(status.total).to eq(5)
    end

    it "treats an empty results list as not-applicable" do
      status = described_class.from_results([])
      expect(status.total).to eq(0)
      expect(status).to be_not_applicable
    end

    it "ignores unknown result strings in the tally (but still counts toward total)" do
      results = [{ "result" => "pass" }, { "result" => "weird" }]
      status = described_class.from_results(results)
      expect(status.pass).to eq(1)
      expect(status.fail).to eq(0)
      expect(status.not_supported).to eq(0)
      expect(status.total).to eq(2)
    end
  end

  describe "#to_matrix_symbol" do
    it "returns 'not-applicable' when total is zero" do
      status = described_class.from_results([])
      expect(status.to_matrix_symbol).to eq("not-applicable")
    end

    it "returns 'pass' when every result is pass" do
      status = described_class.from_results([
        { "result" => "pass" }, { "result" => "pass" },
      ])
      expect(status.to_matrix_symbol).to eq("pass")
    end

    it "returns 'fail' when every result is fail or error" do
      status = described_class.from_results([
        { "result" => "fail" }, { "result" => "error" },
      ])
      expect(status.to_matrix_symbol).to eq("fail")
    end

    it "returns 'not-supported' when every result is not-supported" do
      status = described_class.from_results([
        { "result" => "not-supported" }, { "result" => "not-supported" },
      ])
      expect(status.to_matrix_symbol).to eq("not-supported")
    end

    it "returns 'partial' when some pass and some fail" do
      status = described_class.from_results([
        { "result" => "pass" }, { "result" => "fail" },
      ])
      expect(status.to_matrix_symbol).to eq("partial")
    end

    it "returns 'fail' when no passes but failures exist alongside not-supported" do
      status = described_class.from_results([
        { "result" => "fail" }, { "result" => "not-supported" },
      ])
      expect(status.to_matrix_symbol).to eq("fail")
    end

    it "returns 'not-supported' when only not-supported with zero passes and zero fails" do
      status = described_class.from_results([
        { "result" => "not-supported" }, { "result" => "not-supported" },
      ])
      expect(status.to_matrix_symbol).to eq("not-supported")
    end
  end

  describe "predicates" do
    it "exposes not_applicable? / all_pass? / all_fail? / all_not_supported? / partial?" do
      expect(described_class.from_results([])).to be_not_applicable
      expect(described_class.from_results([{ "result" => "pass" }])).to be_all_pass
      expect(described_class.from_results([{ "result" => "fail" }])).to be_all_fail
      expect(described_class.from_results([{ "result" => "not-supported" }])).to be_all_not_supported
      expect(described_class.from_results([
        { "result" => "pass" }, { "result" => "fail" },
      ])).to be_partial
    end
  end
end
