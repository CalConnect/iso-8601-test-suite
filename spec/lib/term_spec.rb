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
end
