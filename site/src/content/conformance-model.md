# The conformance model

This document defines the vocabulary used across the suite: requirements, requirements classes, conformance tests, conformance classes, profiles, declared conformance, and how they interact to produce a per-library pass/fail determination.

It assumes you've read [the README's data model section](https://github.com/CalConnect/iso-8601-test-suite/blob/main/README.adoc#data-model) for the basic terminology. This document goes deeper on declared vs. not-declared semantics, which is the single most common source of confusion when reading reports.

## The five core terms

| Term | Definition
|---|---
| **Requirement** | A single, testable assertion about ISO 8601 syntax. Carries an `id` (`req:...`), a clause URN pointing into the standard, a `statement`, and optional `format` and `pattern` hints. Lives in `requirements/8601-{1,2}/*.yaml`.
| **Requirements class** | A named group of requirements covering a feature area (calendar date, time-of-day, duration, etc.). Carries an `id` (`req-class:...`) and a `dependencies` list. Maps 1:1 to a conformance class.
| **Conformance test** | A test case targeting one or more requirements. Carries an `id` (`conf-test:...`), a `test_type`, a `given:` block (input), and an `expect:` block (asserted outcome). Lives in `tests/8601-{1,2}/*.yaml`. See [test types](/docs/test-types).
| **Conformance class** | The set of conformance tests for a requirements class. Carries an `id` (`conf-class:...`). A library "conforms to" a conformance class by passing its tests (subject to the declared-conformance rules below).
| **Profile** | A selection of conformance classes (and a subset of their requirements) representing a published subset of ISO 8601 — RFC 3339, W3C Datetime, EDTF, etc. Carries an `id` (`profile:...`), `traceability`, optional `additional_requirements`, and optional `additional_tests`. Lives in `profiles/*.yaml`.

## The two-axis result model

Every (library, test) pair produces one of five outcomes. These are the *supported* axis:

- `pass` — adapter returned the expected result.
- `fail` — adapter returned something different from expected.
- `not-supported` — adapter declared the class but cannot perform this specific operation (e.g. arithmetic on a class that only supports parsing).

And the *declared* axis:

- `not-declared` — the library did not claim to implement the conformance class this test belongs to. The test is recorded but does not count against the library's pass rate.

The interaction:

```
                    declared           not declared
                    ---------          -----------
  test passes       pass               not-declared
  test fails        fail               not-declared
  cannot perform    not-supported      not-declared
  parsing error     fail               not-declared
```

`not-declared` is not a failure. It is an honest statement of scope. A library that declares only `conf-class:calendar-date` and `conf-class:time-of-day` will have every test outside those two classes recorded as `not-declared`, and its pass rate is computed over its declared classes only.

## Why the declared axis exists

Without the declared axis, the only fair comparison would be "every library against every test". This penalizes libraries that scope themselves narrowly on purpose (e.g. a duration-only library would appear to "fail" 90% of tests).

The declared axis lets each library say "here is what I implement" and be scored only on that. The trade-off is that the `declared_conformance_classes` field in each result file must be set honestly:

- **Underscoping** (declaring fewer classes than you implement) is safe but undercounts your pass rate.
- **Overscoping** (declaring classes you don't implement) tanks your pass rate because every test in the undeclared-but-claimed class will fail.

The suite cannot detect overscoping automatically. It is the library author's responsibility.

## Per-class determination

For each conformance class a library declares, the harness aggregates per-test results into a class-level status:

- `pass` — every test in the class passes.
- `partial` — some tests pass, some fail (mixed).
- `fail` — every test fails.
- `not-supported` — every test returns not-supported (the library declared the class but cannot exercise it through the adapter).

These map to the per-class colors on the dashboard.

## Per-profile determination

Profiles aggregate across the conformance classes they select:

1. **Build the requirement set**: every requirement ID selected by the profile's `traceability`, plus every `additional_requirement` the profile adds.
2. **For each conformance class the profile selects**:
   1. Run every test in that class that targets a selected requirement.
   2. Determine the per-library status for the class (`pass`, `fail`, `not-supported`, `partial`).
3. **Aggregate per library across the profile**:
   1. `full` — every selected class passes.
   2. `partial` — at least one class passes or is partial, with no class solely failing.
   3. `none` — no class passes.
4. **Profile-specific requirements** (under `additional_requirements`) are tested as their own virtual class and included in the aggregate.

A library's `profiles_tested` field on its result file determines which profiles the library *claims* to target. Untargeted profiles are still computed for informational purposes, but don't count toward the library's declared conformance.

## How to read a report

Given a result file (`results/<lib>.yaml`) or its dashboard rendering:

1. **Read `declared_conformance_classes` first.** This is the scope of every number that follows.
2. **Check the overall pass rate.** Computed over declared classes only. A library at 80% over 9 declared classes is doing better than one at 100% over 2.
3. **Scan per-class statuses.** A `partial` on a class you depend on is a yellow flag — open the class to see which tests fail.
4. **Drill into per-test detail for failures.** Each failure shows the input, expected, actual, the API the adapter called, and notes from the adapter.
5. **Read `profiles_tested`.** A library's profile determinations are meaningful only for profiles it claims to target.

## Common confusions

### "Why does my library show `not-supported` for class X?"

Either (a) the class requires an operation (e.g. arithmetic) your adapter does not implement, or (b) your `declared_conformance_classes` lists the class but the adapter returns not-supported for every test. Check the adapter's `run_arithmetic`, `generate`, and `equivalent?` methods.

### "Why is my pass rate lower than I expected?"

Most commonly: overscoping. Check whether `declared_conformance_classes` includes a class you don't actually implement. Every test in that class records as `fail`, dragging down the percentage.

### "Why does the dashboard show a profile determination of `none` for my library?"

Either (a) the library didn't include this profile in `profiles_tested`, or (b) every class the profile selects fails or is not-supported. Check the per-class breakdown on the profile detail page.

## Where to go next

- [Test types](/docs/test-types) — the six (now five in current use) test types and what each measures.
- [Identifier scheme](/docs/identifier-scheme) — CURIE-style local IDs and RFC 5141 URN expansion.
- [For implementers](/docs/implementers) — how the model plays out when writing an adapter.
- [For profile authors](/docs/profile-authors) — how the model plays out when defining a profile.
