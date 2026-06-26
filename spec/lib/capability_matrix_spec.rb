# frozen_string_literal: true

require "tmpdir"
require "tempfile"
require_relative "../../lib/test_suite/capability_matrix"

RSpec.describe CapabilityMatrix do
  describe "ADAPTER_DEFS" do
    it "is a non-empty frozen array of hashes" do
      expect(described_class::ADAPTER_DEFS).to be_an(Array)
      expect(described_class::ADAPTER_DEFS).to be_frozen
      expect(described_class::ADAPTER_DEFS.length).to be > 10
    end

    it "every entry has the required keys" do
      required = [:id, :name, :family, :logo, :adapter].sort
      described_class::ADAPTER_DEFS.each do |entry|
        missing = required - entry.keys
        expect(missing).to be_empty, "entry #{entry[:id]} missing: #{missing.inspect}"
      end
    end

    it "every id is unique" do
      ids = described_class::ADAPTER_DEFS.map { |e| e[:id] }
      expect(ids.length).to eq(ids.uniq.length)
    end

    it "every id matches the lowercase CURIE-like pattern" do
      described_class::ADAPTER_DEFS.each do |entry|
        expect(entry[:id]).to match(/\A[a-z][a-z0-9-]*\z/)
      end
    end

    it "every family is a non-empty string" do
      described_class::ADAPTER_DEFS.each do |entry|
        expect(entry[:family]).to be_a(String)
        expect(entry[:family]).not_to be_empty
      end
    end

    it "every logo references a known static asset path" do
      described_class::ADAPTER_DEFS.each do |entry|
        expect(entry[:logo]).to match(%r{\A/logos/[a-z0-9-]+\.svg\z})
      end
    end

    it "every adapter starts with exec: or is a named adapter id" do
      described_class::ADAPTER_DEFS.each do |entry|
        adapter = entry[:adapter]
        expect(adapter).to match(/\A(exec:|[a-z][a-z0-9-]*\z)/)
      end
    end

    it "families partition the adapter set (every entry belongs to a family)" do
      families = described_class::ADAPTER_DEFS.group_by { |e| e[:family] }
      expect(families.length).to be > 1
      families.each do |family, members|
        expect(members.length).to be >= 1
        logos = members.map { |m| m[:logo] }.uniq
        expect(logos.length).to eq(1),
          "family '#{family}' has mixed logos: #{logos.inspect}"
      end
    end
  end

  describe ".load_adapter_defs" do
    it "loads the bundled config and returns an array of symbol-keyed hashes" do
      defs = described_class.load_adapter_defs(described_class::CONFIG_PATH)
      expect(defs).to be_an(Array)
      expect(defs.length).to be > 10
      defs.each do |entry|
        expect(entry.keys).to contain_exactly(:id, :name, :family, :logo, :adapter)
      end
    end

    it "interpolates ${name} references against the paths section" do
      config = <<~YAML
        paths:
          ruby_bin: "/usr/bin/ruby"
        adapters:
          - id: ruby-custom
            name: "Ruby Custom"
            family: "Ruby"
            logo: "/logos/ruby.svg"
            adapter: "exec:${ruby_bin} adapters/ruby/date-exec.rb"
      YAML
      Tempfile.create(["adapters", ".yaml"]) do |f|
        f.write(config); f.flush
        defs = described_class.load_adapter_defs(f.path)
        expect(defs.first[:adapter]).to eq("exec:/usr/bin/ruby adapters/ruby/date-exec.rb")
      end
    end

    it "always exposes ${repo_root} even when not declared in paths" do
      config = <<~YAML
        adapters:
          - id: test-adapter
            name: "Test"
            family: "Test"
            logo: "/logos/test.svg"
            adapter: "exec:${repo_root}/bin/tool"
      YAML
      Tempfile.create(["adapters", ".yaml"]) do |f|
        f.write(config); f.flush
        defs = described_class.load_adapter_defs(f.path)
        expect(defs.first[:adapter]).to eq("exec:#{described_class::REPO_ROOT}/bin/tool")
      end
    end

    it "leaves unknown ${name} references intact for diagnosability" do
      config = <<~YAML
        adapters:
          - id: test-adapter
            name: "Test"
            family: "Test"
            logo: "/logos/test.svg"
            adapter: "exec:${unknown_tool} arg"
      YAML
      Tempfile.create(["adapters", ".yaml"]) do |f|
        f.write(config); f.flush
        defs = described_class.load_adapter_defs(f.path)
        expect(defs.first[:adapter]).to eq("exec:${unknown_tool} arg")
      end
    end

    it "raises KeyError when an entry omits a required field" do
      config = <<~YAML
        adapters:
          - id: incomplete
            name: "Missing fields"
      YAML
      Tempfile.create(["adapters", ".yaml"]) do |f|
        f.write(config); f.flush
        expect { described_class.load_adapter_defs(f.path) }.to raise_error(KeyError)
      end
    end
  end
end
