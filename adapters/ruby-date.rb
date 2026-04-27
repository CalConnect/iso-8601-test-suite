# frozen_string_literal: true

# =============================================================================
# Ruby stdlib Date/DateTime/Time Adapter
# =============================================================================
# Tests Ruby's standard library date/time classes against the ISO 8601
# conformance test suite. No gem dependencies.
#
# Usage:  ruby run-tests --adapter ruby-date
# =============================================================================

require 'date'
require 'time'

class RubyDateAdapter
  def name
    "Ruby Date/DateTime/Time"
  end

  def language
    "ruby"
  end

  def version
    RUBY_VERSION
  end

  # ── Parse an expression ────────────────────────────────────────────────

  def try_parse(expression)
    apis = select_apis(expression)

    apis.each do |api|
      begin
        parsed = case api
                 when :date_parse      then Date.parse(expression)
                 when :date_iso8601    then Date.iso8601(expression)
                 when :datetime_parse  then DateTime.parse(expression)
                 when :datetime_iso8601 then DateTime.iso8601(expression)
                 when :time_parse      then Time.parse(expression)
                 end
        return { valid: true, parsed: parsed, api: api_to_s(api) }
      rescue
        next
      end
    end

    { valid: false, error: "parse error", api: api_to_s(apis.first) }
  end

  # ── Extract components from a parsed object ────────────────────────────

  def extract_components(parsed)
    result = {}

    if parsed.is_a?(Date) || parsed.is_a?(DateTime)
      cal = { year: parsed.year }
      cal[:month] = parsed.month if parsed.respond_to?(:month)
      cal[:day] = parsed.day if parsed.respond_to?(:day)
      result[:calendar] = cal

      if parsed.respond_to?(:cwyear)
        result[:week] = { week_year: parsed.cwyear, week: parsed.cweek, day_of_week: parsed.cwday }
      end

      if parsed.respond_to?(:yday)
        result[:ordinal] = { year: parsed.year, day_of_year: parsed.yday }
      end
    end

    if parsed.is_a?(Time) || parsed.is_a?(DateTime)
      result[:time] = { hour: parsed.hour, minute: parsed.min, second: parsed.sec }

      if parsed.respond_to?(:utc_offset) && parsed.utc_offset != 0
        off = parsed.utc_offset
        result[:time][:utc_offset] = {
          sign: off >= 0 ? "+" : "-",
          hours: off.abs / 3600,
          minutes: (off.abs % 3600) / 60
        }
      end
    end

    result
  end

  # ── Generate an expression from components ─────────────────────────────

  def generate(components)
    cal = components[:calendar] || components["calendar"]
    ordinal = components[:ordinal] || components["ordinal"]
    week = components[:week] || components["week"]

    if cal
      return generate_calendar(cal, components)
    elsif ordinal
      return generate_ordinal(ordinal)
    elsif week
      return generate_week(week)
    end

    nil
  end

  # ── Check equivalence ──────────────────────────────────────────────────

  def equivalent?(parsed_a, parsed_b)
    return nil unless parsed_a && parsed_b

    # Both Date-ish
    if parsed_a.is_a?(Date) && parsed_b.is_a?(Date)
      return parsed_a == parsed_b
    end

    # Both Time/DateTime-ish — compare as timestamps
    if (parsed_a.is_a?(Time) || parsed_a.is_a?(DateTime)) &&
       (parsed_b.is_a?(Time) || parsed_b.is_a?(DateTime))
      return parsed_a.to_time.to_i == parsed_b.to_time.to_i rescue false
    end

    # Mixed
    if parsed_a.is_a?(Date) && (parsed_b.is_a?(Time) || parsed_b.is_a?(DateTime))
      return parsed_a == parsed_b.to_date rescue false
    end
    if parsed_b.is_a?(Date) && (parsed_a.is_a?(Time) || parsed_a.is_a?(DateTime))
      return parsed_a.to_date == parsed_b rescue false
    end

    nil
  end

  # ── Arithmetic: not supported ──────────────────────────────────────────

  def run_arithmetic(_test)
    { result: "not-supported", notes: "Ruby stdlib does not support ISO 8601 arithmetic" }
  end

  private

  # Select which parsing APIs to try, based on expression content
  def select_apis(expr)
    # Duration, interval, recurring — no Ruby stdlib support
    if expr.start_with?("P") || expr.include?("/") || expr.start_with?("R")
      return [:date_parse]
    end

    # Part 2 features — qualification, unspecified, exponential, seasons,
    # grouped units, sets, explicit representation
    if expr.match?(/[?~%]/) || expr.match?(/X/) ||
       expr.match?(/\d+E[-+]?\d/i) || expr.match?(/[UG]/) ||
       expr.match?(/[{}\[\]]/) || expr.match?(/\d[YMDSH]/)
      return [:date_parse]
    end

    # Time-only expressions
    if expr.start_with?("T") || expr.match?(/^\d{1,2}:\d{2}/)
      return [:time_parse, :datetime_parse]
    end

    # Date-time expressions (contain T or timezone offset)
    if expr.include?("T") || expr.match?(/\d[+-]\d{2}/)
      return [:time_parse, :datetime_parse, :date_parse]
    end

    # Expanded year (+/- prefix)
    if expr.match?(/^[+-]/)
      return [:date_iso8601, :date_parse]
    end

    # Basic date-only
    [:date_parse, :date_iso8601]
  end

  def api_to_s(api)
    { date_parse: "Date.parse", date_iso8601: "Date.iso8601",
      datetime_parse: "DateTime.parse", datetime_iso8601: "DateTime.iso8601",
      time_parse: "Time.parse" }[api] || api.to_s
  end

  def generate_calendar(cal, components)
    year   = cal[:year] || cal["year"]
    month  = cal[:month] || cal["month"]
    day    = cal[:day] || cal["day"]
    decade = cal[:decade] || cal["decade"]
    century = cal[:century] || cal["century"]
    expanded = components[:expanded] || components["expanded"]

    if decade
      { expression: decade.to_s }
    elsif century
      { expression: century.to_s }
    elsif year && month && day
      d = Date.new(year, month, day)
      fmt = expanded ? sprintf("+%04d-%02d-%02d", year, month, day) : d.strftime("%Y-%m-%d")
      { expression: fmt }
    elsif year && month
      { expression: sprintf("%04d-%02d", year, month) }
    elsif year
      { expression: year.to_s }
    else
      nil
    end
  end

  def generate_ordinal(ordinal)
    year = ordinal[:year] || ordinal["year"]
    yday = ordinal[:day_of_year] || ordinal["day_of_year"]
    return nil unless year && yday

    d = Date.ordinal(year, yday)
    { expression: d.strftime("%Y-%j") }
  end

  def generate_week(week)
    week_year = week[:week_year] || week["week_year"]
    week_num  = week[:week] || week["week"]
    day_of_week = week[:day_of_week] || week["day_of_week"]

    return nil unless week_year && week_num

    d = Date.commercial(week_year, week_num, day_of_week || 1)
    fmt = day_of_week ? d.strftime("%G-W%V-%u") : d.strftime("%G-W%V")
    { expression: fmt }
  end
end
