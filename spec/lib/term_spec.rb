# frozen_string_literal: true

require_relative "../../lib/test_suite/term"

RSpec.describe Term do
  describe ".colors_enabled?" do
    it "returns false when NO_COLOR is set" do
      original = ENV["NO_COLOR"]
      begin
        ENV["NO_COLOR"] = "1"
        expect(Term.colors_enabled?).to eq(false)
      ensure
        ENV["NO_COLOR"] = original
      end
    end
  end

  describe ".color?" do
    it "returns plain text when colors are disabled" do
      expect(Term.color?(Term::RED, "hello")).to eq("hello")
    end
  end

  describe ".ok_icon" do
    it "returns a string" do
      expect(Term.ok_icon).to be_a(String)
    end
  end

  describe ".fail_icon" do
    it "returns a string" do
      expect(Term.fail_icon).to be_a(String)
    end
  end

  describe ".badge" do
    it "returns a string containing the badge text" do
      expect(Term.badge("PASSED")).to include("PASSED")
    end
  end

  describe ".hr" do
    it "returns a horizontal rule of the right width" do
      result = Term.hr("─", 10)
      expect(result).to include("─")
    end
  end

  describe "ICONS" do
    it "is a frozen hash keyed by section type" do
      expect(described_class::ICONS).to be_frozen
      expect(described_class::ICONS).to be_a(Hash)
    end

    it "every value is a non-empty string (no whitespace-only placeholders)" do
      described_class::ICONS.each do |key, value|
        expect(value).to be_a(String), "#{key} has non-string icon #{value.inspect}"
        expect(value.strip).not_to be_empty, "#{key} has blank icon"
      end
    end

    it "includes entries for every section type used by the validate script" do
      used = [:syntax, :schema, :requirements, :tests, :coverage, :profiles,
              :results, :dag, :source_consistency, :statistics, :orphans,
              :components, :urn_format, :patterns, :naming, :test_reqs]
      used.each { |k| expect(described_class::ICONS).to have_key(k) }
    end
  end

  describe ".section_icon" do
    it "returns an empty string when emoji are disabled" do
      original = ENV["NO_COLOR"]
      begin
        ENV["NO_COLOR"] = "1"
        expect(described_class.section_icon(:syntax)).to eq("")
      ensure
        ENV["NO_COLOR"] = original
      end
    end
  end
end
