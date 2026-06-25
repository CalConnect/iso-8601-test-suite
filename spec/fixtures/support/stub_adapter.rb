# frozen_string_literal: true
#
# Minimal JSON-protocol adapter stub used by spec/lib/exec_adapter_spec.rb.
# Implements just enough of the ExecAdapter protocol to exercise the
# request/response loop, error handling, and missing-field defaults.
#
# Response envelope rules:
#   { result: <value> } → success
#   { error: <string> } → JSON-RPC-style error (raises in ExecAdapter#call)
#   nil                 → unknown method, defaults to error envelope

require "json"

loop do
  line = STDIN.gets
  break if line.nil?

  req = JSON.parse(line.chomp)
  method = req["method"]
  params = req["params"] || {}

  result, error =
    case method
    when "info"
      [{ "name" => "Stub Adapter", "language" => "ruby", "version" => "stub-1.0" }, nil]
    when "declared_conformance_classes"
      [["conf-class:fundamentals"], nil]
    when "declared_profiles"
      [["profile:iso-8601-1-core"], nil]
    when "qualification_notes"
      [["note-one", "note-two"], nil]
    when "try_parse"
      expr = params["expression"]
      if expr == "BAD"
        [{ "valid" => false, "error" => "stub rejection", "api" => "stub" }, nil]
      else
        [{ "valid" => true, "parsed" => { "expression" => expr }, "api" => "stub" }, nil]
      end
    when "extract_components"
      [{ "year" => 1985, "month" => 4 }, nil]
    when "generate"
      [{ "expression" => "1985-04-12" }, nil]
    when "equivalent"
      [params["parsed_a"] == params["parsed_b"], nil]
    when "run_arithmetic"
      # run_arithmetic wraps its argument as {"test": <test>}, so the marker
      # lives one level down.
      if params.dig("test", "_force_error")
        [nil, "stub-side failure"]
      else
        [{ "result" => "pass", "actual" => "stub-result" }, nil]
      end
    else
      [nil, "unknown method #{method}"]
    end

  response = error ? { "error" => error } : { "result" => result }
  STDOUT.puts(response.to_json)
  STDOUT.flush
end
