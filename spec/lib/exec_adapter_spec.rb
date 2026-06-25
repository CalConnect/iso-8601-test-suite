# frozen_string_literal: true

require_relative "../../lib/test_suite/exec_adapter"

RSpec.describe ExecAdapter do
  let(:stub_path) { fixture_path("support", "stub_adapter.rb") }
  let(:malformed_path) { fixture_path("support", "malformed_adapter.rb") }
  let(:ruby) { ENV.fetch("STUB_ADAPTER_RUBY", "ruby") }

  let(:adapter) { described_class.new("#{ruby} #{stub_path}") }

  describe "#initialize" do
    it "raises RuntimeError when the adapter process cannot start" do
      expect {
        described_class.new("exec:/this/command/does/not/exist/xyz123")
      }.to raise_error(RuntimeError, /Cannot start adapter process/)
    end
  end

  describe "info-derived readers" do
    it "exposes name/language/version from the info response" do
      expect(adapter.name).to eq("Stub Adapter")
      expect(adapter.language).to eq("ruby")
      expect(adapter.version).to eq("stub-1.0")
    end
  end

  describe "#declared_conformance_classes" do
    it "returns the array from the declared_conformance_classes response" do
      expect(adapter.declared_conformance_classes).to eq(["conf-class:fundamentals"])
    end
  end

  describe "#declared_profiles" do
    it "returns the array from the declared_profiles response" do
      expect(adapter.declared_profiles).to eq(["profile:iso-8601-1-core"])
    end
  end

  describe "#qualification_notes" do
    it "returns the array from the qualification_notes response" do
      expect(adapter.qualification_notes).to eq(["note-one", "note-two"])
    end
  end

  describe "#try_parse" do
    it "returns a valid hash with parsed payload for accepted expressions" do
      result = adapter.try_parse("1985-04-12")
      expect(result["valid"]).to be true
      expect(result["parsed"]).to eq({ "expression" => "1985-04-12" })
      expect(result["api"]).to eq("stub")
    end

    it "returns an invalid hash with an error message for rejected expressions" do
      result = adapter.try_parse("BAD")
      expect(result["valid"]).to be false
      expect(result["error"]).to eq("stub rejection")
      expect(result["api"]).to eq("stub")
    end
  end

  describe "#extract_components" do
    it "returns the component hash from the response" do
      result = adapter.extract_components("anything")
      expect(result).to eq({ "year" => 1985, "month" => 4 })
    end
  end

  describe "#generate" do
    it "returns an expression hash from the response" do
      result = adapter.generate({ "year" => 1985 })
      expect(result).to eq({ "expression" => "1985-04-12" })
    end
  end

  describe "#equivalent?" do
    it "returns true when the stub judges the two parsed values equal" do
      expect(adapter.equivalent?({ "v" => 1 }, { "v" => 1 })).to be true
    end

    it "returns false when the stub judges them unequal" do
      expect(adapter.equivalent?({ "v" => 1 }, { "v" => 2 })).to be false
    end
  end

  describe "#run_arithmetic" do
    it "returns the result hash from the response" do
      result = adapter.run_arithmetic({ "expression" => "1+1" })
      expect(result["result"]).to eq("pass")
      expect(result["actual"]).to eq("stub-result")
    end
  end

  describe "error propagation" do
    it "raises when the adapter returns an error envelope" do
      # Pass _force_error via the test params; the stub returns an error envelope
      # for run_arithmetic when this flag is set. ExecAdapter#call re-raises the
      # error string, and run_arithmetic does not rescue, so the raise propagates.
      expect {
        adapter.run_arithmetic({ "_force_error" => true })
      }.to raise_error(RuntimeError, /stub-side failure/)
    end
  end

  describe "malformed JSON response" do
    let(:bad_adapter) { described_class.new("#{ruby} #{malformed_path}") }

    it "uses safe fallback defaults when JSON parsing fails" do
      # info() also goes through safe_call, so adapter construction succeeds but
      # all readers fall back to defaults. name falls back to the first token
      # of the command (the ruby binary), not the script basename.
      expect(bad_adapter.name).to eq("ruby")
      expect(bad_adapter.language).to eq("unknown")
      expect(bad_adapter.version).to eq("unknown")
      expect(bad_adapter.declared_conformance_classes).to be_nil
      expect(bad_adapter.qualification_notes).to eq([])
    end

    it "try_parse returns a failure hash when the response is unparseable" do
      result = bad_adapter.try_parse("anything")
      expect(result["valid"]).to be false
      expect(result["api"]).to eq("exec")
    end
  end
end
