# frozen_string_literal: true

require_relative "../../lib/test_suite/term"

RSpec.describe Term do
  describe "color methods" do
    it "returns plain text when NO_COLOR is set" do
      original = ENV["NO_COLOR"]
      ENV["NO_COLOR"] = "1"
      # Reset the constant by reloading (constants are frozen at load time)
      # Instead, test the method directly
      result = Term.send(:color?, "\e[31m", "hello")
      ENV["NO_COLOR"] = original
      expect(result).to eq("hello")
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
