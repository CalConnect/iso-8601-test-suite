#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# Ruby stdlib Date/DateTime/Time Adapter (JSON protocol)
# =============================================================================
# Wraps RubyDateAdapter for the exec: protocol. Version-agnostic — the Ruby
# runtime that executes this file determines which stdlib version is under
# test. ADAPTER_DEFS specifies which ruby binary invokes this file per entry.
#
# Usage: invoked via exec:<path-to-ruby> adapters/ruby/date-exec.rb
# =============================================================================

require "json"
require_relative "date"

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
    ruby_major_minor = RUBY_VERSION.split('.')[0..1].join('.')
    { "name" => "Ruby #{ruby_major_minor} Date", "language" => adapter.language, "version" => adapter.version }
  },

  "declared_conformance_classes" => ->(_params) {
    adapter.declared_conformance_classes
  },

  "declared_profiles" => ->(_params) {
    adapter.declared_profiles
  },

  "try_parse" => ->(params) {
    result = adapter.try_parse(params["expression"], params["options"] || {})
    if result["valid"]
      { "valid" => true, "parsed" => store(result["parsed"]), "api" => result["api"] }
    else
      { "valid" => false, "error" => result["error"], "api" => result["api"] }
    end
  },

  "extract_components" => ->(params) {
    parsed = lookup(params["parsed"])
    result = adapter.extract_components(parsed)
    stringify_keys(result)
  },

  "generate" => ->(params) {
    result = adapter.generate(params["components"])
    result ? { "expression" => result["expression"] } : nil
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
