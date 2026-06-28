# frozen_string_literal: true

require "yaml"

# Loads adapter definitions from config/adapters.yaml.
#
# Two concerns sit here that the CapabilityMatrix orchestrator does not
# need to know about:
#   * path interpolation — the config's `adapter:` field may reference
#     named path entries (${name}) plus the built-in ${repo_root}
#   * frozen registry — ADAPTER_DEFS is materialized once at load time
#     and reused by every CapabilityMatrix instance as the default
#     adapter set
module AdapterConfig
  CONFIG_PATH = File.expand_path(File.join(__dir__, "..", "..", "config", "adapters.yaml"))
  REPO_ROOT   = File.expand_path(File.join(__dir__, "..", ".."))

  # Load adapter definitions from a YAML config file.
  #
  # The config has two sections:
  #   paths:    name → filesystem path (may use ~ for home)
  #   adapters: list of {id, name, family, logo, adapter}
  #
  # The `adapter` field may reference path entries via ${name} interpolation,
  # plus the built-in ${repo_root} for repo-relative references.
  def self.load_adapter_defs(config_path = CONFIG_PATH)
    raw = YAML.load_file(config_path)
    paths = (raw["paths"] || {}).each_with_object({}) do |(k, v), h|
      h[k.to_s] = v.to_s
    end
    paths["repo_root"] = REPO_ROOT

    (raw["adapters"] || []).map do |entry|
      {
        id:      entry.fetch("id"),
        name:    entry.fetch("name"),
        family:  entry.fetch("family"),
        logo:    entry.fetch("logo"),
        adapter: interpolate_paths(entry.fetch("adapter"), paths),
      }
    end
  end

  def self.interpolate_paths(template, vars)
    template.gsub(/\$\{([a-z0-9_]+)\}/i) do
      key = Regexp.last_match(1)
      vars.key?(key) ? vars[key] : "${#{key}}"
    end
  end
  private_class_method :interpolate_paths

  ADAPTER_DEFS = load_adapter_defs.freeze
end
