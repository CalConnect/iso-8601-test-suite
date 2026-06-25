# frozen_string_literal: true

require "open3"

RSpec.describe "scripts/run-tests", :type => :integration do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:script)    { File.join(repo_root, "scripts", "run-tests") }

  def run_runner(*args)
    cmd = ["ruby", script, *args]
    Open3.capture3(*cmd, chdir: repo_root)
  end

  describe "--list" do
    it "exits 0 and lists adapters, profiles, and conformance classes" do
      stdout, _stderr, status = run_runner("--list")
      expect(status.exitstatus).to eq(0)

      expect(stdout).to include("Adapters:")
      expect(stdout).to include("Profiles:")
      expect(stdout).to include("Conformance classes:")

      expect(stdout).to include("ruby-date")
      expect(stdout).to include("profile:iso-8601-1-core")
      expect(stdout).to include("conf-class:fundamentals")
    end
  end

  describe "--adapter ruby-date" do
    it "runs the fundamentals class and emits a summary line" do
      stdout, _stderr, status = run_runner(
        "--adapter", "ruby-date",
        "--class", "conf-class:fundamentals",
        "--quiet"
      )

      expect(stdout).to include("ISO 8601 Test Runner")
      expect(stdout).to include("Adapter: Ruby Date/DateTime/Time")
      expect(stdout).to match(/\d+ tests:.*passed.*failed.*errors.*not-supported/)

      # Exit code is 0 only if no failures/errors. ruby-date has known
      # limitations so we don't assert a specific code — just that the
      # script terminates and produces well-formed output.
      expect([0, 1]).to include(status.exitstatus)
    end
  end

  describe "--help" do
    it "exits 0 and prints the option banner" do
      stdout, _stderr, status = run_runner("--help")
      expect(status.exitstatus).to eq(0)
      expect(stdout).to include("Usage: ruby run-tests")
      expect(stdout).to include("--adapter")
      expect(stdout).to include("--profile")
      expect(stdout).to include("--class")
      expect(stdout).to include("--output")
    end
  end

  describe "unknown adapter" do
    it "exits 1 and reports the error to stderr" do
      _stdout, stderr, status = run_runner("--adapter", "nonexistent-adapter")
      expect(status.exitstatus).to eq(1)
      expect(stderr).to match(/ERROR/i)
    end
  end
end
