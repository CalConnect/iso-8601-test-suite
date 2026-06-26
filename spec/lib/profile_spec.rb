# frozen_string_literal: true

require_relative "../../lib/test_suite/profile"

RSpec.describe Profile do
  describe "accessors" do
    it "exposes top-level fields from the raw hash" do
      profile = Profile.new({
        "id" => "profile:rfc-3339",
        "name" => "RFC 3339",
        "description" => "  Date and Time on the Internet  ",
        "source" => ["https://www.rfc-editor.org/rfc/rfc3339.txt"],
      })

      expect(profile.id).to eq("profile:rfc-3339")
      expect(profile.name).to eq("RFC 3339")
      expect(profile.description).to eq("  Date and Time on the Internet  ")
      expect(profile.description_stripped).to eq("Date and Time on the Internet")
      expect(profile.source).to eq(["https://www.rfc-editor.org/rfc/rfc3339.txt"])
    end

    it "defaults collections to empty arrays when missing" do
      profile = Profile.new({ "id" => "profile:x" })
      expect(profile.traceability).to eq([])
      expect(profile.conformance_classes).to eq([])
      expect(profile.additional_requirements).to eq([])
      expect(profile.additional_tests).to eq([])
    end
  end

  describe "#traceability_entries" do
    it "returns TraceabilityEntry structs from explicit traceability" do
      profile = Profile.new({
        "traceability" => [
          { "conformance_class" => "conf-class:calendar-date", "requirements" => %w[req:a req:b] },
          { "conformance_class" => "conf-class:time-of-day", "requirements" => [] },
        ],
      })

      entries = profile.traceability_entries
      expect(entries.length).to eq(2)
      expect(entries.first).to be_a(Profile::TraceabilityEntry)
      expect(entries.first.conformance_class).to eq("conf-class:calendar-date")
      expect(entries.first.requirements).to eq(%w[req:a req:b])
      expect(entries.last.requirements).to eq([])
    end

    it "synthesizes empty-requirement entries from legacy conformance_classes" do
      profile = Profile.new({ "conformance_classes" => ["conf-class:a", "conf-class:b"] })

      entries = profile.traceability_entries
      expect(entries.length).to eq(2)
      expect(entries.first.conformance_class).to eq("conf-class:a")
      expect(entries.first.requirements).to eq([])
    end

    it "prefers explicit traceability when both forms are present" do
      profile = Profile.new({
        "traceability" => [{ "conformance_class" => "conf-class:from-traceability", "requirements" => [] }],
        "conformance_classes" => ["conf-class:from-legacy"],
      })

      entries = profile.traceability_entries
      expect(entries.length).to eq(1)
      expect(entries.first.conformance_class).to eq("conf-class:from-traceability")
    end

    it "returns empty array when neither form is present" do
      expect(Profile.new.traceability_entries).to eq([])
    end
  end

  describe "#traceability_count and #additional_test_count" do
    it "counts traceability entries" do
      profile = Profile.new({
        "traceability" => [
          { "conformance_class" => "conf-class:a", "requirements" => [] },
          { "conformance_class" => "conf-class:b", "requirements" => [] },
        ],
      })
      expect(profile.traceability_count).to eq(2)
    end

    it "counts additional_tests" do
      profile = Profile.new({
        "additional_tests" => [
          { "id" => "conf-test:x-001" },
          { "id" => "conf-test:x-002" },
          { "id" => "conf-test:x-003" },
        ],
      })
      expect(profile.additional_test_count).to eq(3)
    end
  end
end
