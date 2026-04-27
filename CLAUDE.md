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
- `adapters/` — Pluggable implementation adapters (TEMPLATE.rb + implementations)
- `schema/` — YAML Schema definitions (5 files)
- `requirements/8601-1/` — Part 1 requirements classes (9 files, 99 requirements)
- `requirements/8601-2/` — Part 2 requirements classes (13 files, 158 requirements)
- `tests/8601-1/` — Part 1 conformance classes (9 files, 275 tests)
- `tests/8601-2/` — Part 2 conformance classes (13 files, 363 tests)
- `profiles/` — Profile definitions (7 files)
- `results/` — Conformance test results per implementation (TEMPLATE.yaml + result files)

## Conventions

- Documentation uses AsciiDoc (`.adoc`)
- Test data uses YAML (`.yaml`) with YAML Schema validation
- This is an ISO standards project; precision in terminology and formatting matters
- Each YAML file includes `# yaml-language-server: $schema=...` for editor validation
- Run `ruby scripts/validate` after any changes to YAML files
