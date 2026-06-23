# frozen_string_literal: true

# =============================================================================
# Adapter Template
# =============================================================================
# An adapter wraps a specific date/time implementation so the test harness
# (run-tests) can execute conformance tests against it.
#
# To create a new adapter:
#   1. Copy this file to adapters/{name}.rb
#   2. Rename the class to match your implementation
#   3. Implement the three required methods below
#   4. Run: ruby run-tests --adapter {name}
#
# The harness calls these methods to execute each test type:
#
#   Test type    Adapter method used
#   ---------    ------------------------------------------------
#   validity     try_parse(expression, options)
#   parsing      try_parse(expression, options) + extract_components(parsed)
#   generation   generate(components)
#   equivalence  try_parse(a) + try_parse(b) + equivalent?(obj_a, obj_b)
#   round_trip   try_parse(expr) + extract_components + generate + compare
#   arithmetic   (no adapter method — returns not-supported unless overridden)
#
# Parsing modes (options[:parse_mode]):
#   "dedicated"       — format-specific parser (e.g. strptime with explicit format)
#   "undifferentiated" — general/lenient parser (e.g. Date.parse, Date.iso8601)
#
# =============================================================================

class TemplateAdapter
  # ── Required metadata ──────────────────────────────────────────────────

  # Human-readable name of the implementation
  def name
    "Template Implementation"
  end

  # Programming language
  def language
    "template"
  end

  # Version string of the implementation being tested
  def version
    "0.0.0"
  end

  # ── Optional: declare which conformance classes this implementation targets ─
  #
  # Return an Array of conformance class IDs (e.g. "conf-class:calendar-date")
  # that this implementation intends to conform to. Tests belonging to classes
  # NOT in this list will be marked "not-supported" instead of "fail".
  #
  # Return nil or an empty Array to indicate "all classes" (default behavior).
  #
  def declared_conformance_classes
    nil
  end

  # ── Optional: declare which profiles this implementation targets ──────────
  #
  # Return an Array of profile IDs (e.g. "profile:iso-8601-1-core") that
  # this implementation explicitly claims conformance to. When non-empty,
  # this overrides any inference from declared_conformance_classes and is
  # used by the dashboard to scope per-library statistics to the relevant
  # requirements.
  #
  # Return nil or an empty Array if no profile claim is being made; the
  # dashboard will then infer target profiles from declared_conformance_classes.
  #
  def declared_profiles
    nil
  end

  # ── Required: parse an expression ──────────────────────────────────────
  #
  # The harness calls this for validity, parsing, and round_trip tests.
  #
  # Input:  expression (String) — the ISO 8601 expression to parse
  #         options (Hash) — optional:
  #           :parse_mode — "dedicated" or "undifferentiated" (default: "dedicated")
  #             "dedicated" — use format-specific parsing (e.g. strptime)
  #             "undifferentiated" — use general/lenient parsing (e.g. Date.parse)
  # Return: a Hash with one of two shapes:
  #
  #   Parse succeeded:
  #     { valid: true, parsed: <any object>, api: "Class.method" }
  #
  #   Parse failed:
  #     { valid: false, error: "error message", api: "Class.method" }
  #
  # The `parsed` object is passed back to `extract_components` and
  # `equivalent?` — it can be any type your adapter uses internally.
  #
  def try_parse(expression, options = {})
    # Example:
    #   begin
    #     result = MyDate.parse(expression)
    #     { valid: true, parsed: result, api: "MyDate.parse" }
    #   rescue => e
    #     { valid: false, error: e.message, api: "MyDate.parse" }
    #   end
    { valid: false, error: "not implemented", api: "none" }
  end

  # ── Required: extract components from a parsed object ───────────────────
  #
  # The harness calls this for parsing tests to compare extracted components
  # against the expected values in the YAML test definition.
  #
  # Input:  parsed — the object returned by try_parse in the :parsed field
  # Return: a Hash with component keys matching the YAML test schema:
  #
  #   {
  #     calendar: { year: 1985, month: 4, day: 12 },
  #     ordinal:  { year: 1985, day_of_year: 102 },
  #     week:     { week_year: 1985, week: 15, day_of_week: 5 },
  #     time:     { hour: 23, minute: 20, second: 50,
  #                 utc_offset: { sign: "+", hours: 1, minutes: 0 } },
  #     duration: { years: 1, months: 2, days: 10, hours: 2, minutes: 30 },
  #     interval: { start: { calendar: {...}, time: {...} },
  #                 end:   { calendar: {...}, time: {...} } }
  #   }
  #
  # Include only the keys that the implementation can extract.
  # Return an empty Hash {} if extraction is not possible.
  #
  def extract_components(parsed)
    # Example:
    #   { calendar: { year: parsed.year, month: parsed.month, day: parsed.day } }
    {}
  end

  # ── Required: generate an expression from components ────────────────────
  #
  # The harness calls this for generation tests.
  #
  # Input:  components (Hash) — the `given.components` from the YAML test
  # Return: a Hash with one of two shapes:
  #
  #   Generation succeeded:
  #     { expression: "1985-04-12" }
  #
  #   Generation not supported:
  #     nil
  #
  def generate(components)
    # Example:
    #   cal = components[:calendar]
    #   return nil unless cal && cal[:year] && cal[:month] && cal[:day]
    #   { expression: sprintf("%04d-%02d-%02d", cal[:year], cal[:month], cal[:day]) }
    nil
  end

  # ── Required: check if two parsed objects are equivalent ────────────────
  #
  # The harness calls this for equivalence tests.
  #
  # Input:  parsed_a, parsed_b — objects from try_parse
  # Return: true, false, or nil (cannot determine)
  #
  def equivalent?(parsed_a, parsed_b)
    # Example:
    #   return nil unless parsed_a && parsed_b
    #   parsed_a == parsed_b
    nil
  end

  # ── Optional: override for arithmetic tests ────────────────────────────
  #
  # By default the harness returns "not-supported" for arithmetic tests.
  # Override this method if your implementation supports ISO 8601 arithmetic.
  #
  # Input:  test (Hash) — the full test definition from YAML
  # Return: a result Hash, same as what run_test returns:
  #   { result: "pass" | "fail" | "not-supported" | "error",
  #     actual: { ... },
  #     notes: "..." }
  #
  def run_arithmetic(test)
    { result: "not-supported", notes: "#{name} does not support ISO 8601 arithmetic" }
  end
end
