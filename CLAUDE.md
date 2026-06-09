# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ISO 8601 machine-readable test suite, developed under ISO/TC 154/WG 5. Contains conformance tests for ISO 8601-1:2026 and ISO 8601-2:2026 date/time format syntaxes in a format-agnostic YAML data model. Also defines ISO 8601 Profiles (RFC 3339, W3C DateTime, EDTF Level 0/1/2).

## Data Model

Uses OGC ModSpec terminology: **Requirement**, **Requirements class**, **Conformance test**, **Conformance class**, **Profile**. Each conformance class corresponds 1:1 to a requirements class. Profiles are sets of conformance classes.

Identifiers use CURIE-like local IDs: `suite:name`, `req-class:name`, `req:name`, `conf-class:name`, `conf-test:name`, `profile:name`, `result:name`. Cross-part references use `8601-1:` or `8601-2:` prefix.

Clause references in requirements use RFC 5141 partial URNs: `iso:8601:-{part}:ed-1:en:clause:{number}` (e.g. `iso:8601:-1:ed-1:en:clause:5.2.2.1`).

## Directory Structure

- `suite.yaml` — Machine-readable suite manifest
- `scripts/run-tests` — Test runner (`ruby scripts/run-tests`)
- `scripts/validate` — Validation script (`ruby scripts/validate`)
- `scripts/capability-matrix` — Cross-adapter capability matrix generator
- `lib/test_suite.rb` — Entry point; autoloads all modules
- `lib/test_suite/` — Shared Ruby modules used by all scripts
  - `load_result.rb` — Success/failure value object for YamlStore returns
  - `yaml_store.rb` — Cached YAML file loader, returns LoadResult
  - `suite_index.rb` — Cross-reference index (IDs → files, test → class mapping, ID normalization)
  - `component_vocab.rb` — Component vocabulary loaded from `schema/components.yaml`
  - `stats.rb` — Error/warning/pass tracker with savepoint rollback
  - `schema_validator.rb` — YAML Schema validation engine
  - `test_type_handlers.rb` — Test type handler registry (OCP)
  - `test_suite_loader.rb` — Test list builder from suite index
  - `adapter_loader.rb` — Adapter discovery and instantiation (raises AdapterNotFoundError)
  - `exec_adapter.rb` — JSON protocol adapter for external processes
  - `graph_util.rb` — Directed cycle detection
  - `term.rb` — Terminal output (colors, icons, formatting)
  - `capability_matrix.rb` — Cross-adapter comparison and JSON output
- `adapters/` — Pluggable implementation adapters (TEMPLATE.rb + implementations)
- `schema/` — YAML Schema definitions (7 files including components.yaml and meta.yaml)
- `requirements/8601-1/` — Part 1 requirements classes (9 files)
- `requirements/8601-2/` — Part 2 requirements classes (13 files)
- `tests/8601-1/` — Part 1 conformance classes (9 files)
- `tests/8601-2/` — Part 2 conformance classes (13 files)
- `profiles/` — Profile definitions (7 files)
- `results/` — Conformance test results per implementation (TEMPLATE.yaml + result files)
- `spec/` — RSpec test suite (`bundle exec rspec`)

## Architecture

Scripts use `require_relative '../lib/test_suite'` as the single entry point. All modules are autoloaded on first reference. The design follows OCP (Open-Closed Principle):
- **Phase registry** (validate): add validation phases by appending to the `build_phases` array
- **Test type handler registry** (run-tests): add test types by appending to the `HANDLERS` hash
- **Data-driven component validation**: keys loaded from `schema/components.yaml`, not hardcoded
- **Data-driven class inference**: test→class mapping built by `SuiteIndex`, not hardcoded prefix logic
- **ID normalization in SuiteIndex**: `bare_id` and `resolve_class` centralize bare/prefixed ID handling

### Key design decisions

- **LoadResult value object**: `YamlStore.load` returns `LoadResult.success(data)` or `LoadResult.failure(message)`. Consumers use `result.success?`/`result.failure?` predicates, never hash probing.
- **Stats savepoint**: `Stats#savepoint { }` returns the number of errors added inside the block and auto-rolls them back. Used by `SchemaValidator` for oneOf validation.
- **Exceptions for adapter errors**: `AdapterLoader` raises `AdapterNotFoundError` instead of printing+exit. Scripts handle formatting.
- **String keys throughout**: Adapter return hashes use string keys (`{ "valid" => true }`). No symbol/string key bridging needed.
- **Defensive accessors**: `Stats#errors` and `Stats#warnings` return frozen copies; consumers cannot mutate internals.

## Conventions

- Documentation uses AsciiDoc (`.adoc`)
- Test data uses YAML (`.yaml`) with YAML Schema validation
- Adapter return values use string keys
- lib/ modules never use `Term` for output — they raise exceptions or return data
- This is an ISO standards project; precision in terminology and formatting matters
- Each YAML file includes `# yaml-language-server: $schema=...` for editor validation
- Run `ruby scripts/validate` after any changes to YAML files
- Run `bundle exec rspec` to verify module specs
