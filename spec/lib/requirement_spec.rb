# frozen_string_literal: true

require_relative "../../lib/test_suite/requirement"

RSpec.describe Requirement do
  let(:clause_urn) { "urn:iso:std:iso:8601:-1:ed-1:en:clause:5.2.2.1:tech:cal-date-basic-full" }

  describe "accessors" do
    it "exposes top-level fields from the raw hash" do
      req = Requirement.new({
        "id" => "req:cal-date-basic-full",
        "statement" => "  A calendar date in basic format...  ",
        "format" => "basic",
        "clause" => clause_urn,
        "pattern" => "[YYYY][MM][DD]",
      })

      expect(req.id).to eq("req:cal-date-basic-full")
      expect(req.statement).to eq("A calendar date in basic format...")
      expect(req.format).to eq("basic")
      expect(req.clause).to eq(clause_urn)
      expect(req.pattern).to eq("[YYYY][MM][DD]")
    end

    it "strips whitespace from statement" do
      req = Requirement.new({ "statement" => "  trimmed  " })
      expect(req.statement).to eq("trimmed")
    end

    it "returns nil for missing fields" do
      req = Requirement.new({ "id" => "req:x" })
      expect(req.statement).to be_nil
      expect(req.format).to be_nil
      expect(req.clause).to be_nil
      expect(req.pattern).to be_nil
    end

    it "captures source metadata via constructor kwargs" do
      req = Requirement.new(
        { "id" => "req:x" },
        source_class: "req-class:foo",
        category: "Foo",
      )
      expect(req.source_class).to eq("req-class:foo")
      expect(req.source_profile).to be_nil
      expect(req.category).to eq("Foo")
      expect(req.profile_sourced?).to eq(false)
    end

    it "reports profile_sourced? true when source_profile is set" do
      req = Requirement.new({ "id" => "req:x" }, source_profile: "profile:edtf-level-0")
      expect(req.profile_sourced?).to eq(true)
    end
  end

  describe "#section" do
    it "derives 'Part N §X.Y.Z' from a clause URN" do
      req = Requirement.new({ "clause" => clause_urn })
      expect(req.section).to eq("Part 1 §5.2.2.1")
    end

    it "strips the :tech: disambiguator from the section number" do
      req = Requirement.new({ "clause" => "urn:iso:std:iso:8601:-2:ed-1:en:clause:4.3.4.1:tech:week-date-basic" })
      expect(req.section).to eq("Part 2 §4.3.4.1")
    end

    it "returns the clause verbatim when no :clause: delimiter is present" do
      req = Requirement.new({ "clause" => "some-other-format" })
      expect(req.section).to eq("some-other-format")
    end

    it "returns nil when clause is absent" do
      expect(Requirement.new.section).to be_nil
    end

    it "uses '?' when the part cannot be parsed from the URN" do
      req = Requirement.new({ "clause" => "urn:iso:std:iso:8601:-X:ed-1:en:clause:1.2" })
      expect(req.section).to eq("Part ? §1.2")
    end
  end

  describe "#part" do
    it "uses explicit part when provided" do
      req = Requirement.new({ "clause" => clause_urn }, part: "profile")
      expect(req.part).to eq("profile")
    end

    it "derives part from clause URN when not explicit" do
      req = Requirement.new({ "clause" => clause_urn })
      expect(req.part).to eq("1")
    end

    it "derives '2' from a Part 2 clause URN" do
      req = Requirement.new({ "clause" => "urn:iso:std:iso:8601:-2:ed-1:en:clause:4.1" })
      expect(req.part).to eq("2")
    end

    it "returns nil when neither explicit part nor parseable clause" do
      expect(Requirement.new.part).to be_nil
    end
  end
end
