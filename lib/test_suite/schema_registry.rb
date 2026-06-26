# frozen_string_literal: true

# Authoritative mapping from data file paths (repo-relative) to their
# YAML schema files. Replaces the comment-regex lookup that lived in
# YamlStore#schema_ref for the validator's purposes.
#
# The `# yaml-language-server: $schema=...` comments at the top of each
# data file stay as IDE hints for inline validation, but the validator
# now goes through this registry so the contract lives in one place.
# The comments can drift (e.g. config/adapters.yaml references a
# non-existent adapters-schema.yaml) without affecting validation.
#
# Adding a new schema mapping is appending one entry to MAPPING — OCP.
module SchemaRegistry
  # Ordered list of [matcher, schema_path] pairs. First match wins.
  # Match patterns may be:
  #   * String  — exact repo-relative path match
  #   * Regexp  — matched against the repo-relative path
  MAPPING = [
    [/\Asuite\.yaml\z/,             "schema/suite.yaml"],
    [%r{\Arequirements/.*\.yaml\z}, "schema/requirements-class.yaml"],
    [%r{\Atests/.*\.yaml\z},        "schema/conformance-class.yaml"],
    [%r{\Aprofiles/.*\.yaml\z},     "schema/profile.yaml"],
    [%r{\Aresults/.*\.yaml\z},      "schema/conformance-result.yaml"],
  ].freeze

  module_function

  def schema_for(repo_relative_path)
    entry = MAPPING.find { |matcher, _| match?(matcher, repo_relative_path) }
    entry&.last
  end

  def match?(matcher, path)
    return path == matcher if matcher.is_a?(String)
    path.match?(matcher)
  end
  private_class_method :match?
end
