# frozen_string_literal: true

# Read-only value object wrapping a conformance-test Hash loaded from YAML.
# Provides typed accessors for the polymorphic given/expect shapes defined in
# schema/conformance-class.yaml and derived predicates used by handlers.
class Test
  attr_reader :id, :description, :test_type, :requirements,
              :parse_mode, :given, :expect, :raw

  BASIC_FORMAT_SUFFIX = "-basic"

  def initialize(raw = {})
    @raw          = raw
    @id           = raw["id"]
    @description  = raw["description"]
    @test_type    = raw["test_type"]
    @requirements = raw["requirements"] || []
    @parse_mode   = raw["parse_mode"]
    @given        = raw["given"] || {}
    @expect       = raw["expect"] || {}
  end

  def expression          = given["expression"]
  def expression_a        = given["expression_a"]
  def expression_b        = given["expression_b"]
  def given_components    = given["components"]

  def expected_valid      = expect["valid"]
  def expected_components = expect["components"]
  def expected_expression = expect["expression"]
  def expected_equivalent = expect["equivalent"]

  def basic_format?
    requirements.any? { |r| r.to_s.end_with?(BASIC_FORMAT_SUFFIX) }
  end

  def parse_options
    parse_mode ? { parse_mode: parse_mode } : {}
  end
end
