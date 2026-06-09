# frozen_string_literal: true

require 'json'
require 'open3'

class ExecAdapter
  def initialize(command)
    @command = command
    begin
      @stdin, @stdout, @wait_thr = Open3.popen2(command)
    rescue Errno::ENOENT, Errno::EACCES => e
      raise RuntimeError, "Cannot start adapter process: #{command}\n  #{e.message}"
    end
    @info = safe_call("info") || {}
  end

  def name     = @info["name"] || File.basename(@command.split.first || @command)
  def language = @info["language"] || "unknown"
  def version  = @info["version"] || "unknown"

  def declared_conformance_classes
    @declared_ccs ||= safe_call("declared_conformance_classes")
  end

  def try_parse(expression, options = {})
    result = call("try_parse", "expression" => expression, "options" => options)
    unless result
      return { "valid" => false, "error" => "no response from adapter process", "api" => "exec" }
    end
    if result["valid"]
      { "valid" => true, "parsed" => result["parsed"], "api" => result["api"] || "exec" }
    else
      { "valid" => false, "error" => result["error"] || "parse error", "api" => result["api"] || "exec" }
    end
  rescue => e
    { "valid" => false, "error" => e.message, "api" => "exec" }
  end

  def extract_components(parsed)
    call("extract_components", "parsed" => parsed) || {}
  end

  def generate(components)
    result = call("generate", "components" => components)
    result ? { "expression" => result["expression"] } : nil
  end

  def equivalent?(parsed_a, parsed_b)
    call("equivalent", "parsed_a" => parsed_a, "parsed_b" => parsed_b)
  end

  def run_arithmetic(test)
    call("run_arithmetic", "test" => test) ||
      { "result" => "not-supported", "notes" => "No response from adapter process" }
  end

  private

  def call(method, params = {})
    request = { "method" => method, "params" => params }.to_json
    @stdin.puts(request)
    @stdin.flush
    line = @stdout.gets
    return nil unless line
    response = JSON.parse(line.strip)
    raise response["error"] if response["error"]
    response["result"]
  rescue JSON::ParserError
    nil
  end

  def safe_call(method, params = {})
    call(method, params)
  rescue
    nil
  end
end
