# frozen_string_literal: true

require_relative "../../lib/test_suite/stats"

RSpec.describe Stats do
  subject(:stats) { described_class.new }

  describe "#ok?" do
    it "returns true when no errors" do
      expect(stats).to be_ok
    end

    it "returns false after an error" do
      stats.error("file.yaml", "bad")
      expect(stats).not_to be_ok
    end
  end

  describe "#error" do
    it "records an error with path and message" do
      stats.error("file.yaml", "something wrong")
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first).to eq({ path: "file.yaml", msg: "something wrong" })
    end
  end

  describe "#warn" do
    it "records a warning with path and message" do
      stats.warn("file.yaml", "suspicious")
      expect(stats.warnings.length).to eq(1)
      expect(stats.warnings.first).to eq({ path: "file.yaml", msg: "suspicious" })
    end
  end

  describe "#pass!" do
    it "increments the pass counter" do
      expect { stats.pass! }.to change { stats.passed }.by(1)
    end
  end

  describe "#file!" do
    it "increments the file counter" do
      expect { stats.file! }.to change { stats.total_files }.by(1)
    end
  end

  describe "#error_count_snapshot" do
    it "returns the current error count" do
      expect(stats.error_count_snapshot).to eq(0)
      stats.error("f", "e")
      expect(stats.error_count_snapshot).to eq(1)
    end
  end

  describe "#errors" do
    it "returns a frozen copy" do
      errors = stats.errors
      expect(errors).to be_frozen
      expect { errors << { path: "x", msg: "y" } }.to raise_error(FrozenError)
    end

    it "does not expose internal state" do
      stats.error("f", "e")
      returned = stats.errors
      expect(returned.length).to eq(1)
      # Mutating the returned copy doesn't affect internal state
      expect { returned.clear }.to raise_error(FrozenError)
      expect(stats.errors.length).to eq(1)
    end
  end

  describe "#warnings" do
    it "returns a frozen copy" do
      warnings = stats.warnings
      expect(warnings).to be_frozen
    end
  end

  describe "#savepoint" do
    it "rolls back errors added inside the block" do
      stats.error("before", "existing")
      added = stats.savepoint do
        stats.error("inside", "temporary")
        stats.error("also inside", "temporary")
      end
      expect(added).to eq(2)
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:path]).to eq("before")
    end

    it "preserves errors added before the block" do
      stats.error("before", "kept")
      stats.savepoint do
        stats.error("inside", "rolled back")
      end
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:path]).to eq("before")
    end

    it "returns 0 when no errors added" do
      added = stats.savepoint { }
      expect(added).to eq(0)
    end

    it "handles nested savepoints" do
      stats.error("a", "1")
      stats.savepoint do
        stats.error("b", "2")
        stats.savepoint do
          stats.error("c", "3")
        end
        # inner savepoint rolled back "c"
        expect(stats.errors.length).to eq(2) # a + b
      end
      # outer savepoint rolled back "b"
      expect(stats.errors.length).to eq(1)
      expect(stats.errors.first[:path]).to eq("a")
    end
  end
end
