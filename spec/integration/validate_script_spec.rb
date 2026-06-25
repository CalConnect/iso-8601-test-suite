# frozen_string_literal: true

require "open3"

RSpec.describe "scripts/validate", :type => :integration do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:script)    { File.join(repo_root, "scripts", "validate") }

  def run_validate(*args)
    cmd = ["ruby", script, *args]
    Open3.capture3(*cmd, chdir: repo_root)
  end

  it "exits 0 and reports 'All checks passed' on the real suite" do
    stdout, _stderr, status = run_validate("-q")
    expect(status.exitstatus).to eq(0)
    expect(stdout).to include("All checks passed")
  end

  it "runs every registered phase and emits a final summary" do
    stdout, _stderr, status = run_validate
    expect(status.exitstatus).to eq(0)

    expected_phases = [
      "YAML Syntax",
      "Schema References",
      "Schema Validation",
      "Requirements Classes",
      "Conformance Classes",
      "Requirements Coverage",
      "Test Requirement References",
      "Profile References",
      "Result Files",
      "Dependency Graph",
      "Source Consistency",
      "Source URN Format",
      "Suite Statistics",
      "Pattern Coverage",
      "Component Validity",
      "Test ID Naming",
    ]
    expected_phases.each do |phase|
      expect(stdout).to include(phase), "phase '#{phase}' missing from output"
    end

    expect(stdout).to include("ALL PASSED")
  end
end
