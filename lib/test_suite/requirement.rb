# frozen_string_literal: true

# Read-only value object wrapping a requirement Hash loaded from YAML.
# Encapsulates the requirement fields plus metadata about its source
# (parent class / profile) and derives the human-readable section label
# from the RFC 5141 clause URN.
class Requirement
  attr_reader :id, :statement, :format, :clause, :pattern,
              :source_class, :source_profile, :category, :raw

  URN_PART_PATTERN = /8601:-([12]):/.freeze
  URN_CLAUSE_DELIM = ":clause:".freeze
  URN_TECH_DELIM    = ":tech:".freeze

  def initialize(raw = {}, source_class: nil, source_profile: nil, category: nil, part: nil)
    @raw            = raw
    @id             = raw["id"]
    @statement      = raw["statement"]&.strip
    @format         = raw["format"]
    @clause         = raw["clause"]
    @pattern        = raw["pattern"]
    @source_class   = source_class
    @source_profile = source_profile
    @category       = category
    @explicit_part  = part
  end

  def part
    @explicit_part || part_from_clause
  end

  def section
    return clause unless clause&.include?(URN_CLAUSE_DELIM)
    "Part #{part_from_clause || '?'} §#{clause_section_number}"
  end

  def profile_sourced?
    !source_profile.nil?
  end

  private

  def part_from_clause
    return nil unless clause
    m = clause.match(URN_PART_PATTERN)
    m && m[1]
  end

  def clause_section_number
    clause.sub(/.*#{URN_CLAUSE_DELIM}/, "").sub(/#{URN_TECH_DELIM}.*$/, "")
  end
end
