# frozen_string_literal: true

# Read-only value object representing a loaded adapter definition.
#
# Built by CapabilityMatrix#load_adapters from two sources:
#   * the static config (config/adapters.yaml) — id, name, family, logo,
#     adapter spec
#   * the loaded adapter instance — adapter, version, language
#
# Replaces the implicit Hash-with-symbol-keys that was passed between
# CapabilityMatrix, MatrixContext, and the four section builders. The
# Hash worked but its contract lived in the heads of the maintainers;
# this object makes it explicit and lets the Ruby type system catch
# typos at the access site.
class AdapterDef
  attr_reader :id, :name, :family, :logo, :adapter, :version, :language

  def initialize(id:, name:, family:, logo:, adapter:, version:, language:)
    @id       = id
    @name     = name
    @family   = family
    @logo     = logo
    @adapter  = adapter
    @version  = version
    @language = language
  end

  def qualification_notes
    adapter&.qualification_notes || []
  end
end
