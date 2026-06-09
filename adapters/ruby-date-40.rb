#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Ruby 4.0 stdlib Date/DateTime/Time Adapter (JSON protocol)
# =============================================================================
# Wraps RubyDateAdapter for the exec: protocol. Runs under Ruby 4.0 to test
# the latest stdlib behavior against the ISO 8601 conformance test suite.
#
# Usage: invoked via exec:~/.local/share/mise/installs/ruby/4.0.5/bin/ruby adapters/ruby-date-40.rb
# =============================================================================

require "json"
require_relative "ruby-date"

adapter = RubyDateAdapter.new

# Object handle cache for passing complex objects through JSON
@cache = {}
@handle_counter = 0

def store(obj)
  @handle_counter += 1
  h = "h#{@handle_counter}"
  @cache[h] = obj
  h
end

def lookup(handle)
  @cache[handle]
end

def stringify_keys(hash)
  return {} unless hash.is_a?(Hash)
  hash.transform_keys(&:to_s)
end

methods = {
  "info" => ->(_params) {
    { "name" => "Ruby 4.0 Date/DateTime/Time", "language" => adapter.language, "version" => adapter.version }
  },

  "declared_conformance_classes" => ->(_params) {
    adapter.declared_conformance_classes
  },

  "try_parse" => ->(params) {
    result = adapter.try_parse(params["expression"], params["options"] || {})
    if result[:valid]
      { "valid" => true, "parsed" => store(result[:parsed]), "api" => result[:api] }
    else
      { "valid" => false, "error" => result[:error], "api" => result[:api] }
    end
  },

  "extract_components" => ->(params) {
    parsed = lookup(params["parsed"])
    result = adapter.extract_components(parsed)
    stringify_keys(result)
  },

  "generate" => ->(params) {
    result = adapter.generate(params["components"])
    result ? { "expression" => result[:expression] } : nil
  },

  "equivalent" => ->(params) {
    a = lookup(params["parsed_a"])
    b = lookup(params["parsed_b"])
    adapter.equivalent?(a, b)
  },

  "run_arithmetic" => ->(params) {
    adapter.run_arithmetic(params["test"])
  },
}

$stdin.each_line do |line|
  line.strip!
  next if line.empty?
  begin
    request = JSON.parse(line)
    method = request["method"]
    params = request["params"] || {}
    handler = methods[method]
    response = handler ? { "result" => handler.call(params) } : { "error" => "Unknown method: #{method}" }
  rescue => e
    response = { "error" => e.message }
  end
  $stdout.puts(JSON.generate(response))
  $stdout.flush
end
