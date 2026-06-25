# frozen_string_literal: true

# Shared terminal output module for ISO 8601 test suite scripts.
# Provides ANSI color output, icons, and formatting helpers.
# Used by both scripts/validate and scripts/run-tests.

module Term
  RESET   = "\e[0m"
  BOLD    = "\e[1m"
  DIM     = "\e[2m"

  RED     = "\e[31m"
  GREEN   = "\e[32m"
  YELLOW  = "\e[33m"
  BLUE    = "\e[34m"
  CYAN    = "\e[36m"
  WHITE   = "\e[37m"

  BRED    = "\e[91m"
  BGREEN  = "\e[92m"
  BYELLOW = "\e[93m"
  BBLUE   = "\e[94m"
  BMAGENTA= "\e[95m"

  BG_RED   = "\e[41m"
  BG_GREEN = "\e[42m"

  ICONS = {
    syntax: "  ",
    schema: "  ",
    requirements: "  ",
    tests: "  ",
    coverage: "  ",
    profiles: "  ",
    results: "  ",
    dag: "  ",
    source_consistency: "  ",
    statistics: "  ",
    orphans: "  ",
    components: "  ",
    urn_format: "  ",
    patterns: "  ",
    naming: "  ",
    test_reqs: "  "
  }.freeze

  module_function

  def colors_enabled?
    $stdout.tty? && ENV["NO_COLOR"].nil?
  end

  def emoji_enabled?
    colors_enabled? && $stdout.tty?
  end

  def color?(code, text)
    colors_enabled? ? "#{code}#{text}#{RESET}" : text.to_s
  end

  def bold(text)    = color?(BOLD, text)
  def dim(text)     = color?(DIM, text)

  def red(text)     = color?(RED, text)
  def green(text)   = color?(GREEN, text)
  def yellow(text)  = color?(YELLOW, text)
  def blue(text)    = color?(BLUE, text)
  def cyan(text)    = color?(CYAN, text)
  def white(text)   = color?(WHITE, text)

  def bred(text)    = color?(BRED, text)
  def bgreen(text)  = color?(BGREEN, text)
  def byellow(text) = color?(BYELLOW, text)
  def bblue(text)   = color?(BBLUE, text)
  def bmag(text)    = color?(BMAGENTA, text)

  def badge(text, color = BG_GREEN)
    colors_enabled? ? " #{color}#{WHITE} #{text} #{RESET} " : " [#{text}] "
  end

  def ok_icon
    emoji_enabled? ? green("  ✓") : green("PASS")
  end

  def fail_icon
    emoji_enabled? ? bred("  ✗") : bred("FAIL")
  end

  def warn_icon
    emoji_enabled? ? byellow("  ⚠") : byellow("WARN")
  end

  def info_icon
    emoji_enabled? ? bblue("  ℹ") : bblue("INFO")
  end

  def section_icon(type)
    return "" unless emoji_enabled?
    ICONS.fetch(type, "  ")
  end

  def hr(char = "─", width = 60)
    dim(char * width)
  end

  def double_hr(width = 60)
    dim("═" * width)
  end
end
