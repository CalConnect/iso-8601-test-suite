# frozen_string_literal: true

require_relative "../../lib/test_suite/graph_util"

RSpec.describe GraphUtil do
  describe ".detect_cycles" do
    it "returns empty for an acyclic graph" do
      adj = { "A" => ["B"], "B" => ["C"], "C" => [] }
      expect(described_class.detect_cycles(adj)).to be_empty
    end

    it "detects a simple self-loop" do
      adj = { "A" => ["A"] }
      cycles = described_class.detect_cycles(adj)
      expect(cycles.length).to eq(1)
      expect(cycles.first).to eq(["A", "A"])
    end

    it "detects a two-node cycle" do
      adj = { "A" => ["B"], "B" => ["A"] }
      cycles = described_class.detect_cycles(adj)
      expect(cycles.length).to eq(1)
      expect(cycles.first).to eq(["A", "B", "A"])
    end

    it "detects a longer cycle" do
      adj = { "A" => ["B"], "B" => ["C"], "C" => ["A"] }
      cycles = described_class.detect_cycles(adj)
      expect(cycles.length).to eq(1)
    end

    it "returns empty for an empty graph" do
      expect(described_class.detect_cycles({})).to be_empty
    end

    it "returns empty for a disconnected acyclic graph" do
      adj = { "A" => [], "B" => [], "C" => [] }
      expect(described_class.detect_cycles(adj)).to be_empty
    end

    it "handles nodes with no adjacency list entry" do
      adj = { "A" => ["B"] }
      # B has no entry — no cycle
      expect(described_class.detect_cycles(adj)).to be_empty
    end
  end
end
