# frozen_string_literal: true

require_relative "../../lib/test_suite/test_type_handlers"

RSpec.describe TestTypeHandlers do
  ParsedObject = Struct.new(:expression)

  let(:adapter) do
    Class.new do
      def try_parse(expr, options = {})
        { "valid" => true, "parsed" => ParsedObject.new(expr), "api" => "stub" }
      end

      def extract_components(parsed)
        { "calendar" => { "year" => 2024, "month" => 1, "day" => 15 } }
      end

      def generate(components)
        { "expression" => "2024-01-15" }
      end

      def equivalent?(a, b)
        a.expression == b.expression
      end

      def run_arithmetic(test)
        { "result" => "not-supported" }
      end
    end.new
  end

  describe ".run" do
    it "delegates to the validity handler" do
      test = {
        "test_type" => "validity",
        "given" => { "expression" => "2024-01-15" },
        "expect" => { "valid" => true }
      }
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("pass")
    end

    it "delegates to the parsing handler" do
      test = {
        "test_type" => "parsing",
        "given" => { "expression" => "2024-01-15" },
        "expect" => { "valid" => true, "components" => { "calendar" => { "year" => 2024 } } }
      }
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("pass")
    end

    it "delegates to the generation handler" do
      test = {
        "test_type" => "generation",
        "given" => { "components" => { "calendar" => { "year" => 2024 } } },
        "expect" => { "expression" => "2024-01-15" }
      }
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("pass")
    end

    it "delegates to the arithmetic handler" do
      test = { "test_type" => "arithmetic" }
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("not-supported")
    end

    it "returns error for unknown test type" do
      result = described_class.run(adapter, { "test_type" => "unknown_type" })
      expect(result["result"]).to eq("error")
      expect(result["notes"]).to include("Unknown test type")
    end
  end

  describe "validity handler" do
    it "fails when actual validity differs from expected" do
      test = {
        "test_type" => "validity",
        "given" => { "expression" => "invalid" },
        "expect" => { "valid" => true }
      }
      allow(adapter).to receive(:try_parse).and_return({ "valid" => false, "error" => "bad", "api" => "stub" })
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("fail")
    end
  end

  describe "parsing handler" do
    it "passes when expected invalid and parse fails" do
      test = {
        "test_type" => "parsing",
        "given" => { "expression" => "garbage" },
        "expect" => { "valid" => false }
      }
      allow(adapter).to receive(:try_parse).and_return({ "valid" => false, "error" => "bad", "api" => "stub" })
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("pass")
    end

    it "fails on component mismatch" do
      test = {
        "test_type" => "parsing",
        "given" => { "expression" => "2024-01-15" },
        "expect" => { "valid" => true, "components" => { "calendar" => { "year" => 1999 } } }
      }
      allow(adapter).to receive(:try_parse).and_return({ "valid" => true, "parsed" => ParsedObject.new("2024-01-15"), "api" => "stub" })
      allow(adapter).to receive(:extract_components).and_return({ "calendar" => { "year" => 2024 } })
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("fail")
    end
  end

  describe "generation handler" do
    it "returns not-supported when adapter returns nil" do
      test = {
        "test_type" => "generation",
        "given" => { "components" => { "calendar" => { "year" => 2024 } } },
        "expect" => { "expression" => "2024-01-15" }
      }
      allow(adapter).to receive(:generate).and_return(nil)
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("not-supported")
    end
  end

  describe "round_trip handler" do
    it "passes when generated matches original" do
      test = {
        "test_type" => "round_trip",
        "given" => { "expression" => "2024-01-15" }
      }
      parsed = ParsedObject.new("2024-01-15")
      allow(adapter).to receive(:try_parse).and_return({ "valid" => true, "parsed" => parsed, "api" => "stub" })
      allow(adapter).to receive(:extract_components).and_return({ "calendar" => { "year" => 2024 } })
      allow(adapter).to receive(:generate).and_return({ "expression" => "2024-01-15" })
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("pass")
    end

    it "fails when parse fails" do
      test = {
        "test_type" => "round_trip",
        "given" => { "expression" => "garbage" }
      }
      allow(adapter).to receive(:try_parse).and_return({ "valid" => false, "error" => "bad", "api" => "stub" })
      result = described_class.run(adapter, test)
      expect(result["result"]).to eq("fail")
    end
  end
end
