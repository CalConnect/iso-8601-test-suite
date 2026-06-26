# frozen_string_literal: true

# Read-only value object wrapping a profile Hash loaded from YAML.
# Exposes profile-level fields and normalizes the traceability matrix
# (handles both the explicit traceability form and the legacy
# conformance_classes form).
class Profile
  TraceabilityEntry = Struct.new(:conformance_class, :requirements)

  attr_reader :id, :name, :description, :source,
              :traceability, :conformance_classes,
              :additional_requirements, :additional_tests, :raw

  def initialize(raw = {})
    @raw                     = raw
    @id                      = raw["id"]
    @name                    = raw["name"]
    @description             = raw["description"]
    @source                  = raw["source"]
    @traceability            = raw["traceability"] || []
    @conformance_classes     = raw["conformance_classes"] || []
    @additional_requirements = raw["additional_requirements"] || []
    @additional_tests        = raw["additional_tests"] || []
  end

  def description_stripped
    description&.strip
  end

  def traceability_entries
    if traceability.any?
      traceability.map { |tc|
        TraceabilityEntry.new(tc["conformance_class"], tc["requirements"] || [])
      }
    elsif conformance_classes.any?
      conformance_classes.map { |cc| TraceabilityEntry.new(cc, []) }
    else
      []
    end
  end

  def traceability_count
    traceability_entries.length
  end

  def additional_test_count
    additional_tests.length
  end
end
