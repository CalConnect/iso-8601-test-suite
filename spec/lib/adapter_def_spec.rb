# frozen_string_literal: true

require_relative "../../lib/test_suite/adapter_def"

NotelessAdapter = Struct.new(:version, :language) do
  def qualification_notes = []
end
NotesAdapter = Struct.new(:version, :language, :notes) do
  def qualification_notes = notes
end

RSpec.describe AdapterDef do
  let(:adapter) { NotelessAdapter.new("1.2", "ruby") }

  let(:defn) do
    described_class.new(
      id: "lib-a", name: "Library A", family: "Ruby",
      logo: "/logos/ruby.svg", adapter: adapter,
      version: "1.2", language: "ruby"
    )
  end

  it "exposes every constructor field as a reader" do
    expect(defn.id).to eq("lib-a")
    expect(defn.name).to eq("Library A")
    expect(defn.family).to eq("Ruby")
    expect(defn.logo).to eq("/logos/ruby.svg")
    expect(defn.adapter).to be(adapter)
    expect(defn.version).to eq("1.2")
    expect(defn.language).to eq("ruby")
  end

  it "qualification_notes delegates to the adapter" do
    with_notes = described_class.new(
      id: "lib-b", name: "B", family: "Ruby", logo: "/logos/ruby.svg",
      adapter: NotesAdapter.new("1.0", "ruby", ["ECO-1", "ECO-2"]),
      version: "1.0", language: "ruby"
    )
    expect(with_notes.qualification_notes).to eq(["ECO-1", "ECO-2"])
  end

  it "qualification_notes returns [] when the adapter has none" do
    expect(defn.qualification_notes).to eq([])
  end

  it "qualification_notes returns [] when adapter is nil" do
    missing = described_class.new(
      id: "lib-nil", name: "Nil", family: "Ruby", logo: "/logos/ruby.svg",
      adapter: nil, version: "?", language: "?"
    )
    expect(missing.qualification_notes).to eq([])
  end
end
