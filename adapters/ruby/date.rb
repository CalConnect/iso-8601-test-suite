# frozen_string_literal: true

# =============================================================================
# Ruby stdlib Date/DateTime/Time Adapter
# =============================================================================
# Tests Ruby's standard library date/time classes against the ISO 8601
# conformance test suite. Uses the full Ruby ecosystem:
#   Parsing:  strptime (format-specific), iso8601 (strict), parse (general)
#   Generation: Date.new/Date.ordinal/Date.commercial/DateTime.new + strftime
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

  def declared_conformance_classes
    %w[
      conf-class:fundamentals
      conf-class:calendar-date
      conf-class:time-of-day
      conf-class:date-and-time
    ]
  end

  def declared_profiles
    %w[profile:iso-8601-1-core]
  end

  def qualification_notes
    nil
  end

  # ── Parse an expression ────────────────────────────────────────────────

  def try_parse(expression, options = {})
    mode = options[:parse_mode] || "dedicated"

    # 1. Dedicated format: strptime with detected format
    if mode == "dedicated"
      result = try_strptime(expression)
      return result if result
    end

    # 2. General/lenient parsers (used directly for undifferentiated mode)
    apis = select_fallback_apis(expression)
    apis.each do |api|
      begin
        parsed = case api
                 when :date_parse       then Date.parse(expression)
                 when :date_iso8601     then Date.iso8601(expression)
                 when :datetime_parse   then DateTime.parse(expression)
                 when :datetime_iso8601 then DateTime.iso8601(expression)
                 when :time_parse       then Time.parse(expression)
                 when :time_iso8601     then Time.iso8601(expression)
                 end
        return { "valid" => true, "parsed" => parsed, "api" => api_to_s(api) }
      rescue
        next
      end
    end

    { "valid" => false, "error" => "parse error", "api" => api_to_s(apis.first) }
  end

  # ── Extract components from a parsed object ────────────────────────────

  def extract_components(parsed)
    result = {}

    if parsed.is_a?(Date) && !parsed.is_a?(DateTime)
      result["calendar"] = { "year" => parsed.year }
      result["calendar"]["month"] = parsed.month if parsed.respond_to?(:month)
      result["calendar"]["day"] = parsed.day if parsed.respond_to?(:day)

      if parsed.respond_to?(:cwyear)
        result["week"] = { "week_year" => parsed.cwyear, "week" => parsed.cweek, "day_of_week" => parsed.cwday }
      end

      if parsed.respond_to?(:yday)
        result["ordinal"] = { "year" => parsed.year, "day_of_year" => parsed.yday }
      end
    end

    if parsed.is_a?(Time)
      result["calendar"] = { "year" => parsed.year, "month" => parsed.month, "day" => parsed.day }
      result["ordinal"] = { "year" => parsed.year, "day_of_year" => parsed.yday }
      result["week"] = { "week_year" => parsed.strftime("%G").to_i, "week" => parsed.strftime("%V").to_i,
                        "day_of_week" => parsed.wday == 0 ? 7 : parsed.wday }
      result["time"] = build_time_components(parsed)
    end

    if parsed.is_a?(DateTime)
      result["calendar"] = { "year" => parsed.year, "month" => parsed.month, "day" => parsed.day }
      result["ordinal"] = { "year" => parsed.year, "day_of_year" => parsed.yday }
      result["week"] = { "week_year" => parsed.cwyear, "week" => parsed.cweek, "day_of_week" => parsed.cwday }
      result["time"] = build_time_components(parsed)
    end

    result
  end

  # ── Generate an expression from components ─────────────────────────────

  def generate(components)
    components = symbolize_keys(components)
    cal       = components[:calendar]
    ordinal   = components[:ordinal]
    week      = components[:week]
    time      = components[:time]
    format    = components[:format]

    if cal
      generate_calendar(cal, time, format, components)
    elsif ordinal
      generate_ordinal(ordinal, time, format)
    elsif week
      generate_week(week, time, format)
    elsif time
      generate_time_only(time, format)
    else
      nil
    end
  end

  # ── Check equivalence ──────────────────────────────────────────────────

  def equivalent?(parsed_a, parsed_b)
    return nil unless parsed_a && parsed_b

    if parsed_a.is_a?(Date) && parsed_b.is_a?(Date)
      return parsed_a == parsed_b
    end

    if (parsed_a.is_a?(Time) || parsed_a.is_a?(DateTime)) &&
       (parsed_b.is_a?(Time) || parsed_b.is_a?(DateTime))
      return parsed_a.to_time.to_i == parsed_b.to_time.to_i rescue false
    end

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
    { "result" => "not-supported", "notes" => "Ruby stdlib does not support ISO 8601 arithmetic" }
  end

  private

  # ── strptime format registry ───────────────────────────────────────────
  # Each entry: [regex, strptime_format, ruby_class]
  # Most specific patterns first. %z handles Z as UTC in Time.strptime.

  STRPTIME_FORMATS = [
    # Calendar date-time, basic format with fractional seconds
    [/\A\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}[.,]\d+Z\z/,                 "%Y%m%dT%H%M%S.%L%z",  Time],
    [/\A\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}[.,]\d+[+-]\d{2}:?\d{2}\z/,  "%Y%m%dT%H%M%S.%L%z",  Time],
    [/\A\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}[.,]\d+\z/,                  "%Y%m%dT%H%M%S.%L",    DateTime],

    # Calendar date-time, basic format
    [/\A\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}Z\z/,                        "%Y%m%dT%H%M%S%z",     Time],
    [/\A\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}[+-]\d{2}:?\d{2}\z/,         "%Y%m%dT%H%M%S%z",     Time],
    [/\A\d{4}\d{2}\d{2}T\d{2}\d{2}\d{2}\z/,                          "%Y%m%dT%H%M%S",       DateTime],

    # Calendar date-time, basic format reduced precision (no seconds)
    [/\A\d{4}\d{2}\d{2}T\d{2}\d{2}Z\z/,                              "%Y%m%dT%H%M%z",       Time],
    [/\A\d{4}\d{2}\d{2}T\d{2}\d{2}[+-]\d{2}:?\d{2}\z/,               "%Y%m%dT%H%M%z",       Time],
    [/\A\d{4}\d{2}\d{2}T\d{2}\d{2}\z/,                                "%Y%m%dT%H%M",         DateTime],

    # Calendar date-time, extended format with fractional seconds
    [/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.,]\d+Z\z/,              "%Y-%m-%dT%H:%M:%S.%L%z", Time],
    [/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.,]\d+[+-]\d{2}:?\d{2}\z/, "%Y-%m-%dT%H:%M:%S.%L%z", Time],
    [/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.,]\d+\z/,              "%Y-%m-%dT%H:%M:%S.%L",   DateTime],

    # Calendar date-time, extended format
    [/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/,                    "%Y-%m-%dT%H:%M:%S%z",    Time],
    [/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:?\d{2}\z/,     "%Y-%m-%dT%H:%M:%S%z",    Time],
    [/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\z/,                      "%Y-%m-%dT%H:%M:%S",      DateTime],

    # Calendar date-time, extended format reduced precision
    [/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}Z\z/,                           "%Y-%m-%dT%H:%M%z",       Time],
    [/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}[+-]\d{2}:?\d{2}\z/,            "%Y-%m-%dT%H:%M%z",       Time],
    [/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}\z/,                             "%Y-%m-%dT%H:%M",         DateTime],

    # Ordinal date-time, basic format
    [/\A\d{4}\d{3}T\d{2}\d{2}\d{2}Z\z/,                              "%Y%jT%H%M%S%z",          Time],
    [/\A\d{4}\d{3}T\d{2}\d{2}\d{2}[+-]\d{2}:?\d{2}\z/,               "%Y%jT%H%M%S%z",          Time],
    [/\A\d{4}\d{3}T\d{2}\d{2}\d{2}\z/,                                "%Y%jT%H%M%S",            DateTime],

    # Ordinal date-time, extended format
    [/\A\d{4}-\d{3}T\d{2}:\d{2}:\d{2}Z\z/,                           "%Y-%jT%H:%M:%S%z",       Time],
    [/\A\d{4}-\d{3}T\d{2}:\d{2}:\d{2}[+-]\d{2}:?\d{2}\z/,            "%Y-%jT%H:%M:%S%z",       Time],
    [/\A\d{4}-\d{3}T\d{2}:\d{2}:\d{2}\z/,                             "%Y-%jT%H:%M:%S",         DateTime],

    # Ordinal date-time, reduced precision
    [/\A\d{4}\d{3}T\d{2}\d{2}Z\z/,                                   "%Y%jT%H%M%z",            Time],
    [/\A\d{4}\d{3}T\d{2}\d{2}[+-]\d{2}:?\d{2}\z/,                    "%Y%jT%H%M%z",            Time],
    [/\A\d{4}\d{3}T\d{2}\d{2}\z/,                                     "%Y%jT%H%M",              DateTime],
    [/\A\d{4}-\d{3}T\d{2}:\d{2}Z\z/,                                  "%Y-%jT%H:%M%z",          Time],
    [/\A\d{4}-\d{3}T\d{2}:\d{2}[+-]\d{2}:?\d{2}\z/,                   "%Y-%jT%H:%M%z",          Time],
    [/\A\d{4}-\d{3}T\d{2}:\d{2}\z/,                                   "%Y-%jT%H:%M",            DateTime],

    # Week date-time, basic format
    [/\A\d{4}W\d{2}\d{T\d{2}\d{2}\d{2}Z\z/,                          "%GW%V%uT%H%M%S%z",       Time],
    [/\A\d{4}W\d{2}\d{T\d{2}\d{2}\d{2}[+-]\d{2}:?\d{2}\z/,           "%GW%V%uT%H%M%S%z",       Time],
    [/\A\d{4}W\d{2}\d{T\d{2}\d{2}\d{2}\z/,                            "%GW%V%uT%H%M%S",         DateTime],

    # Week date-time, extended format
    [/\A\d{4}-W\d{2}-\d{T\d{2}:\d{2}:\d{2}Z\z/,                      "%G-W%V-%uT%H:%M:%S%z",   Time],
    [/\A\d{4}-W\d{2}-\d{T\d{2}:\d{2}:\d{2}[+-]\d{2}:?\d{2}\z/,       "%G-W%V-%uT%H:%M:%S%z",   Time],
    [/\A\d{4}-W\d{2}-\d{T\d{2}:\d{2}:\d{2}\z/,                        "%G-W%V-%uT%H:%M:%S",     DateTime],

    # Week date-time, reduced precision
    [/\A\d{4}W\d{2}\d{T\d{2}\d{2}Z\z/,                               "%GW%V%uT%H%M%z",         Time],
    [/\A\d{4}W\d{2}\d{T\d{2}\d{2}[+-]\d{2}:?\d{2}\z/,                "%GW%V%uT%H%M%z",         Time],
    [/\A\d{4}W\d{2}\d{T\d{2}\d{2}\z/,                                 "%GW%V%uT%H%M",           DateTime],
    [/\A\d{4}-W\d{2}-\d{T\d{2}:\d{2}Z\z/,                             "%G-W%V-%uT%H:%M%z",      Time],
    [/\A\d{4}-W\d{2}-\d{T\d{2}:\d{2}[+-]\d{2}:?\d{2}\z/,              "%G-W%V-%uT%H:%M%z",      Time],
    [/\A\d{4}-W\d{2}-\d{T\d{2}:\d{2}\z/,                              "%G-W%V-%uT%H:%M",        DateTime],

    # Date-only formats
    [/\A\d{4}\d{2}\d{2}\z/,                                           "%Y%m%d",                  Date],
    [/\A\d{4}-\d{2}-\d{2}\z/,                                         "%Y-%m-%d",                Date],
    [/\A\d{4}\d{3}\z/,                                                "%Y%j",                    Date],
    [/\A\d{4}-\d{3}\z/,                                               "%Y-%j",                   Date],
    [/\A\d{4}W\d{2}\d\z/,                                             "%GW%V%u",                 Date],
    [/\A\d{4}-W\d{2}-\d\z/,                                           "%G-W%V-%u",               Date],

    # Time-only, basic format with T prefix
    [/\AT\d{2}\d{2}\d{2}Z\z/,                                         "T%H%M%S%z",               Time],
    [/\AT\d{2}\d{2}\d{2}[+-]\d{2}:?\d{2}\z/,                          "T%H%M%S%z",               Time],
    [/\AT\d{2}\d{2}\d{2}\z/,                                          "T%H%M%S",                 Time],
    [/\AT\d{2}\d{2}Z\z/,                                              "T%H%M%z",                 Time],
    [/\AT\d{2}\d{2}\z/,                                               "T%H%M",                   Time],
    [/\AT\d{2}\z/,                                                    "T%H",                     Time],

    # Time-only, extended format
    [/\A\d{2}:\d{2}:\d{2}[.,]\d+Z\z/,                                 "%H:%M:%S.%L%z",           Time],
    [/\A\d{2}:\d{2}:\d{2}[.,]\d+[+-]\d{2}:?\d{2}\z/,                  "%H:%M:%S.%L%z",           Time],
    [/\A\d{2}:\d{2}:\d{2}[.,]\d+\z/,                                  "%H:%M:%S.%L",             Time],
    [/\A\d{2}:\d{2}:\d{2}Z\z/,                                        "%H:%M:%S%z",              Time],
    [/\A\d{2}:\d{2}:\d{2}[+-]\d{2}:?\d{2}\z/,                         "%H:%M:%S%z",              Time],
    [/\A\d{2}:\d{2}:\d{2}\z/,                                         "%H:%M:%S",                Time],
    [/\A\d{2}:\d{2}Z\z/,                                              "%H:%M%z",                 Time],
    [/\A\d{2}:\d{2}[+-]\d{2}:?\d{2}\z/,                               "%H:%M%z",                 Time],
    [/\A\d{2}:\d{2}\z/,                                               "%H:%M",                   Time],

    # Reduced-precision date-only formats
    [/\A\d{4}-\d{2}\z/,                                               "%Y-%m",                   Date],
    [/\A\d{4}\z/,                                                     "%Y",                      Date],
  ].freeze

  def try_strptime(expr)
    STRPTIME_FORMATS.each do |pattern, fmt, klass|
      next unless expr.match?(pattern)
      begin
        parsed = klass.strptime(expr, fmt)
        return { "valid" => true, "parsed" => parsed, "api" => "#{klass}.strptime" }
      rescue
        next
      end
    end
    nil
  end

  # ── Fallback API selection for general/lenient parsers ────────────────

  def select_fallback_apis(expr)
    # Duration, interval, recurring — limited stdlib support
    if expr.start_with?("P") || expr.include?("/") || expr.start_with?("R")
      return [:date_parse]
    end

    # Part 2 features
    if expr.match?(/[?~%]/) || expr.match?(/X/) ||
       expr.match?(/\d+E[-+]?\d/i) || expr.match?(/[UG]/) ||
       expr.match?(/[{}\[\]]/) || expr.match?(/\d[YMDSH]/)
      return [:date_parse]
    end

    # Time-only expressions
    if expr.start_with?("T") || expr.match?(/\A\d{1,2}:\d{2}/)
      return [:time_parse, :time_iso8601, :datetime_parse]
    end

    # Date-time expressions (contain T separator)
    if expr.include?("T")
      return [:time_iso8601, :time_parse, :datetime_parse, :date_parse]
    end

    # Expanded year (+/- prefix)
    if expr.match?(/\A[+-]/)
      return [:date_iso8601, :date_parse]
    end

    # Date-only
    [:date_parse, :date_iso8601]
  end

  def api_to_s(api)
    { date_parse: "Date.parse", date_iso8601: "Date.iso8601",
      datetime_parse: "DateTime.parse", datetime_iso8601: "DateTime.iso8601",
      time_parse: "Time.parse", time_iso8601: "Time.iso8601"
    }[api] || api.to_s
  end

  # ── Component extraction helpers ─────────────────────────────────────

  def build_time_components(parsed)
    t = { "hour" => parsed.hour, "minute" => parsed.min, "second" => parsed.sec }

    if parsed.respond_to?(:utc_offset) && (parsed.utc_offset != 0 || (parsed.respond_to?(:zone) && parsed.zone == "UTC"))
      off = parsed.utc_offset
      t["utc_offset"] = {
        "sign" => off >= 0 ? "+" : "-",
        "hours" => off.abs / 3600,
        "minutes" => (off.abs % 3600) / 60
      }
    end

    t
  end

  # ── Generation helpers ─────────────────────────────────────────────────

  def generate_calendar(cal, time, format, components)
    h = symbolize_keys(cal)
    year      = h[:year]
    month     = h[:month]
    day       = h[:day]
    expanded  = components[:expanded]

    if year && month && day
      d = Date.new(year, month, day)

      if time
        th = symbolize_keys(time)
        generate_datetime(Date.new(year, month, day), th, format, expanded)
      elsif format == "basic"
        { "expression" => d.strftime("%Y%m%d") }
      elsif expanded
        { "expression" => sprintf("+%04d-%02d-%02d", year, month, day) }
      else
        { "expression" => d.strftime("%Y-%m-%d") }
      end
    elsif year && month
      { "expression" => sprintf("%04d-%02d", year, month) }
    elsif year
      { "expression" => year.to_s }
    else
      nil
    end
  end

  def generate_datetime(date_obj, time_hash, format, expanded)
    hour   = time_hash[:hour]
    minute = time_hash[:minute]
    second = time_hash[:second]
    offset = time_hash[:utc_offset]

    if offset
      off_h = symbolize_keys(offset)
      off_hours = off_h[:hours] || 0
      off_mins = off_h[:minutes] || 0
      off_sign = off_h[:sign] || "+"
      off_rational = Rational(off_sign == "-" ? -1 : 1) * Rational(off_hours * 60 + off_mins, 1440)
    else
      off_rational = Rational(0, 24)
    end

    dt = DateTime.new(date_obj.year, date_obj.month, date_obj.day,
                      hour || 0, minute || 0, second || 0, off_rational)

    if format == "basic"
      tz_str = format_offset_basic(offset)
      { "expression" => dt.strftime("%Y%m%dT%H%M%S") + tz_str }
    elsif off_rational == 0 && offset
      { "expression" => dt.strftime("%Y-%m-%dT%H:%M:%SZ") }
    elsif offset
      { "expression" => dt.strftime("%Y-%m-%dT%H:%M:%S") + format_offset_extended(offset) }
    else
      { "expression" => dt.strftime("%Y-%m-%dT%H:%M:%S") }
    end
  end

  def generate_ordinal(ordinal, time, format)
    h = symbolize_keys(ordinal)
    year = h[:year]
    yday = h[:day_of_year]
    return nil unless year && yday

    d = Date.ordinal(year, yday)

    if time
      th = symbolize_keys(time)
      generate_datetime(d, th, format, nil)
    elsif format == "basic"
      { "expression" => d.strftime("%Y%j") }
    else
      { "expression" => d.strftime("%Y-%j") }
    end
  end

  def generate_week(week, time, format)
    h = symbolize_keys(week)
    week_year  = h[:week_year]
    week_num   = h[:week]
    day_of_week = h[:day_of_week]

    return nil unless week_year && week_num

    d = Date.commercial(week_year, week_num, day_of_week || 1)

    if time
      th = symbolize_keys(time)
      generate_datetime(d, th, format, nil)
    elsif format == "basic"
      { "expression" => d.strftime("%GW%V%u") }
    else
      { "expression" => day_of_week ? d.strftime("%G-W%V-%u") : d.strftime("%G-W%V") }
    end
  end

  def generate_time_only(time, format)
    h = symbolize_keys(time)
    hour   = h[:hour]
    minute = h[:minute]
    second = h[:second]
    offset = h[:utc_offset]

    return nil unless hour

    if format == "basic"
      expr = sprintf("%02d", hour)
      expr << sprintf("%02d", minute) if minute
      expr << sprintf("%02d", second) if second
      expr << format_offset_basic(offset) if offset
      { "expression" => expr }
    else
      if second
        expr = sprintf("%02d:%02d:%02d", hour, minute || 0, second)
      elsif minute
        expr = sprintf("%02d:%02d", hour, minute)
      else
        expr = sprintf("%02d", hour)
      end
      expr << format_offset_extended(offset) if offset
      { "expression" => expr }
    end
  end

  def format_offset_basic(offset)
    return "" unless offset
    h = symbolize_keys(offset)
    return "Z" if h[:hours] == 0 && (h[:minutes] || 0) == 0 && h[:sign] == "+"
    sign = h[:sign] || "+"
    "#{sign}%02d%02d" % [h[:hours] || 0, h[:minutes] || 0]
  end

  def format_offset_extended(offset)
    return "" unless offset
    h = symbolize_keys(offset)
    return "Z" if h[:hours] == 0 && (h[:minutes] || 0) == 0 && h[:sign] == "+"
    sign = h[:sign] || "+"
    "#{sign}%02d:%02d" % [h[:hours] || 0, h[:minutes] || 0]
  end

  def symbolize_keys(hash)
    return {} unless hash.is_a?(Hash)
    hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
  end
end
