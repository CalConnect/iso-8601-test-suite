# frozen_string_literal: true

require_relative "../../lib/test_suite/load_result"
require_relative "../../lib/test_suite/yaml_store"
require_relative "../../lib/test_suite/component_vocab"

RSpec.describe ComponentVocabulary do
  subject(:vocab) { described_class.new(YamlStore.new) }

  describe "#known_top_key?" do
    it "returns true for keys defined at top level" do
      expect(vocab.known_top_key?("calendar")).to be true
    end

    it "returns false for unknown keys" do
      expect(vocab.known_top_key?("nonsense_key_xyz")).to be false
    end
  end

  describe "#known_sub_key?" do
    it "returns true for valid sub keys under a known parent" do
      expect(vocab.known_sub_key?("calendar", "year")).to be true
    end

    it "returns false for unknown sub keys" do
      expect(vocab.known_sub_key?("calendar", "nonexistent")).to be false
    end

    it "returns false when the parent itself is unknown" do
      expect(vocab.known_sub_key?("nonexistent", "year")).to be false
    end
  end

  describe "#top_keys" do
    it "returns a frozen Array" do
      expect(vocab.top_keys).to be_an(Array)
      expect(vocab.top_keys).to be_frozen
    end

    it "includes the canonical calendar key" do
      expect(vocab.top_keys).to include("calendar")
    end
  end

  describe "#sub_keys" do
    it "returns a frozen Array" do
      expect(vocab.sub_keys("calendar")).to be_an(Array)
      expect(vocab.sub_keys("calendar")).to be_frozen
    end

    it "returns an empty array for unknown parents" do
      expect(vocab.sub_keys("nonexistent")).to eq([])
    end
  end
end
