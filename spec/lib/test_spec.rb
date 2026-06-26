# frozen_string_literal: true

require_relative "../../lib/test_suite/test"

RSpec.describe Test do
  describe "accessors" do
    it "exposes top-level fields from the raw hash" do
      test = Test.new(
        "id" => "conf-test:foo-001",
        "description" => "verifies foo",
        "test_type" => "parsing",
        "requirements" => %w[req:foo-a req:foo-b],
        "parse_mode" => "dedicated",
        "given" => { "expression" => "2024-01-15" },
        "expect" => { "valid" => true }
      )

      expect(test.id).to eq("conf-test:foo-001")
      expect(test.description).to eq("verifies foo")
      expect(test.test_type).to eq("parsing")
      expect(test.requirements).to eq(%w[req:foo-a req:foo-b])
      expect(test.parse_mode).to eq("dedicated")
    end

    it "defaults requirements to empty array when missing" do
      test = Test.new("id" => "t-1", "test_type" => "validity")
      expect(test.requirements).to eq([])
    end

    it "defaults given/expect to empty hashes when missing" do
      test = Test.new("id" => "t-1")
      expect(test.given).to eq({})
      expect(test.expect).to eq({})
    end

    it "exposes the raw hash for adapter boundary pass-through" do
      raw = { "id" => "t-1", "test_type" => "arithmetic", "given" => { "expression" => "P1Y" } }
      expect(Test.new(raw).raw).to equal(raw)
    end
  end

  describe "given/expect shape accessors" do
    it "reads expression-style given" do
      test = Test.new("given" => { "expression" => "2024-01-15" })
      expect(test.expression).to eq("2024-01-15")
    end

    it "reads expression_a/expression_b for equivalence tests" do
      test = Test.new("given" => { "expression_a" => "2024", "expression_b" => "2024-00-00" })
      expect(test.expression_a).to eq("2024")
      expect(test.expression_b).to eq("2024-00-00")
    end

    it "reads given_components for generation tests" do
      test = Test.new("given" => { "components" => { "calendar" => { "year" => 2024 } } })
      expect(test.given_components).to eq({ "calendar" => { "year" => 2024 } })
    end

    it "reads expected_valid / expected_components / expected_expression / expected_equivalent" do
      expect(Test.new("expect" => { "valid" => true }).expected_valid).to eq(true)
      expect(Test.new("expect" => { "components" => { "x" => 1 } }).expected_components).to eq({ "x" => 1 })
      expect(Test.new("expect" => { "expression" => "2024" }).expected_expression).to eq("2024")
      expect(Test.new("expect" => { "equivalent" => false }).expected_equivalent).to eq(false)
    end
  end

  describe "#basic_format?" do
    it "returns true when any requirement targets a -basic class" do
      test = Test.new("requirements" => %w[req:calendar-date-basic req:other])
      expect(test.basic_format?).to eq(true)
    end

    it "returns false when no requirement targets a -basic class" do
      test = Test.new("requirements" => %w[req:calendar-date req:other])
      expect(test.basic_format?).to eq(false)
    end

    it "returns false when requirements is empty" do
      expect(Test.new.basic_format?).to eq(false)
    end
  end

  describe "#parse_options" do
    it "includes parse_mode when set" do
      test = Test.new("parse_mode" => "undifferentiated")
      expect(test.parse_options).to eq({ parse_mode: "undifferentiated" })
    end

    it "returns empty hash when parse_mode is absent" do
      expect(Test.new.parse_options).to eq({})
    end
  end
end
