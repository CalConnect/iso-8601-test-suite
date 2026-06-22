# For standards authors

**Audience:** you're a member of ISO/TC 154/WG 5, CalConnect TC DATETIME, or another body responsible for ISO 8601-1:2026, ISO 8601-2:2026, or a profile thereof. You want evidence that the standard is implementable and signals that normative text is ambiguous.

This document assumes you understand the basics from [the conformance model](/docs/conformance-model) and [the identifier scheme](/docs/identifier-scheme). Skim those first if the terminology here is unclear.

## Why this suite exists, from your point of view

A conformance test suite is a standards-quality instrument. Its primary job is not to grade libraries — it is to *expose where the standard itself is ambiguous, under-specified, or unimplementable*. Failures in independent implementations are signal, not noise.

This suite covers 308 requirements across both parts of the standard, organized into 22 conformance classes, exercised against 19 library versions from 7 implementation families (Ruby, Python, Node.js, C, C++, Rust, Java). Every requirement carries a clause URN that points back into the standard, so any failure cluster can be traced to a specific paragraph.

## Using the suite as a standards-quality instrument

Three complementary lenses:

### Lens 1: Coverage

The first question a standards author asks is "is every clause tested?" Each requirement in `requirements/8601-1/` and `requirements/8601-2/` carries a `clause:` field that resolves to an RFC 5141 URN such as:

```
urn:iso:std:iso:8601:-1:ed-1:en:clause:5.2.2.1
```

The suite currently references ~280 unique clause URNs across both parts. To audit coverage:

```bash
# all clause URNs referenced by requirements
grep -h "clause:" requirements/8601-1/*.yaml requirements/8601-2/*.yaml \
  | grep -oE 'clause:[0-9.]+' | sort -u
```

Compare this list to the clause index of the published standard. Gaps — clauses that exist in the standard but have no requirement — are *under-specified requirements*, not bugs in the suite.

### Lens 2: Failure clusters

When three or more independent implementations fail the same conformance test, the most likely explanation is not "three library authors made the same mistake". It is that the standard's wording permits multiple interpretations, or forbids something implementations reasonably want to do.

The dashboard's Matrix view (`/matrix`) shows every requirement × every implementation. Filter by category to scope to a feature area. A column of red cells across multiple families — Ruby, Python, Java all failing the same requirement — is the strongest signal this suite produces.

### Lens 3: Test-level disagreements

Sometimes implementations don't just pass or fail — they *disagree*. Library A parses `2024-W53-1` as 2024-12-30; Library B parses it as invalid; Library C parses it as 2025-12-29. Each individual result may look "correct" under a reasonable reading of the standard, but the disagreement is the signal.

For each such case, click through to the test detail (the dashboard links every matrix cell to the underlying test cases) and read:

- **Input**: the expression the adapter received.
- **Expected**: the component hash the suite asserted.
- **Actual**: what the adapter returned.
- **Notes**: free-form adapter commentary on why it produced that result.

Disagreements are normative-text feedback even when the test's "expected" value is itself debatable. The right question is: "what wording in the standard would resolve this disagreement?"

## Coverage by clause

The suite's traceability is bidirectional:

| Standard clause → Requirement | `requirements/8601-{1,2}/*.yaml` carries `clause:` per requirement
| Requirement → Conformance test | `tests/8601-{1,2}/*.yaml` targets `req:` IDs
| Conformance test → Result     | `results/<lib>.yaml` records per-test outcome
| Result → Adapter              | Adapter log records API call and exception

To find which requirement(s) target a specific clause:

```bash
grep -rn "clause:5.2.2.1" requirements/
```

To find which tests exercise a specific requirement:

```bash
grep -rn "req:cal-date-basic-full" tests/
```

### Spotting under-tested clauses

A clause is under-tested if either:

1. **It is referenced by a requirement but no conformance test targets that requirement.** Run:

   ```bash
   for r in $(grep -h "^  - id: req:" requirements/8601-1/*.yaml | awk '{print $3}'); do
     if ! grep -q "$r" tests/8601-1/*.yaml; then
       echo "no test: $r"
     fi
   done
   ```

   Repeat for `8601-2`. Any output is a coverage hole.

2. **It is tested by only one test type.** A requirement tested only by `parsing` but not by `generation` or `round_trip` is a candidate for ambiguity: implementations may parse the form correctly but produce it differently. Run:

   ```bash
   # requirements with only one test type
   ruby scripts/validate --verbose 2>&1 | grep "single test type"
   ```

## Failure patterns as standards feedback

These patterns recur across independent implementations in the current corpus. For each pattern, the listed clause URNs are the standards-author action items.

### Basic format (`YYYYMMDD`)

The single largest failure cluster. 6 of 7 implementation families reject basic format in at least one class. The standard specifies basic format alongside extended format with equal weight; the implementations read this as "extended is the default, basic is optional".

- **Affected clauses**: `clause:5.2.2.1` (calendar date basic), `clause:5.3.1.1` (time basic), `clause:5.4.1` (date-time basic).
- **Standards-author question**: should the standard distinguish "default format" from "permitted format"? If so, how?

### Week dates, basic form

`YYYYWwwD` fails almost everywhere, even in libraries that handle the extended form `YYYY-Www-D`.

- **Affected clause**: `clause:5.2.3.1`.
- **Standards-author question**: is the basic form of week date useful enough in practice to keep as a normative requirement, or should it be moved to an informative annex?

### 24-hour clock (`24:00:00`)

End-of-day notation. Rejected by Node.js, Java, and several other families as out-of-range. The standard permits it.

- **Affected clause**: `clause:5.3.4.2`.
- **Standards-author question**: should the standard add an explicit non-normative note that `24:00:00` is equivalent to `00:00:00` of the next day, to forestall the "out-of-range hour" reading?

### Time zone designators

`Z`, `+02:00`, `+0200`, `+02` are all permitted. Implementations vary widely in which they accept. The standard treats them uniformly; implementations do not.

- **Affected clause**: `clause:5.3.7`.
- **Standards-author question**: is the four-form list a conformance burden? Should the standard mark some forms as deprecated?

### Century and decade (Part 2)

`19` (century) and `198x` (decade) are unimplemented in every mainstream stdlib. This is partly because Part 2 is newer, but partly because the representations are ambiguous (is `19` a year or a century? depends on context).

- **Affected clauses**: `urn:iso:std:iso:8601:-2:ed-1:en:clause:` for century and decade requirements.
- **Standards-author question**: should the standard disambiguate via length rules, prefix markers, or context only? The current wording relies on context.

### EDTF markers

Uncertain (`1985?`), approximate (`1985~`), unspecified (`1985-XX`). No stdlib in the suite implements these. This is *expected* — EDTF is a profile, not a baseline — but it surfaces a question:

- **Standards-author question**: is the bar for Part 2 conformance "implement everything in the part", or "implement at least the core subset"? The standard should say.

### Time interval abbreviated end

`1985-04-12/15` — the abbreviated end form. Unsupported everywhere.

- **Affected clause**: `clause:7.2` (interval forms).
- **Standards-author question**: is the abbreviated end form a common enough use case to keep normative, or should it be moved to a permissive annex?

## When the test is wrong, not the standard

Not every failure cluster means the standard is ambiguous. Sometimes the test itself is wrong. The triage order:

1. **Read the requirement statement.** Does the test's `expect.components` match the requirement's `statement`? If not, the test is wrong.
2. **Read the clause.** Does the requirement's `statement` faithfully represent the clause? If not, the requirement is wrong.
3. **Read the implementations' notes.** If three independent adapters give three different reasons for failing, the standard is ambiguous. If they give the same reason ("out of range", "no parser"), the implementations are aligned and the standard may simply be asking for something libraries don't prioritize — which is still a signal, but a weaker one.

The suite's validation script (`ruby scripts/validate`) cross-checks the first two of these. The third requires human judgement; this is where standards authors add value.

## Filing feedback

Two channels, depending on what you found:

### Bugs in the suite

Test wrong, requirement wrong, clause reference broken, schema violation:

1. Open an issue at the suite's repository (see the project README for the URL).
2. Include the test ID (`conf-test:...`), the requirement ID (`req:...`), and the observed-vs-expected behavior.
3. Propose replacement language for the requirement or test.

### Feedback on the standard itself

Clause ambiguous, requirement missing, normative text unclear:

1. File through your national body's ISO/TC 154 channel, or via CalConnect TC DATETIME if you are a CalConnect member.
2. Cite the specific clause URN (`urn:iso:std:iso:8601:-{part}:ed-1:en:clause:N`).
3. Reference the failure cluster as evidence: list the implementations that disagree, link to the dashboard matrix view, attach the per-test detail.
4. Propose replacement wording. Concrete proposals get processed faster than observations.

The strongest feedback packages combine (a) the clause citation, (b) the test ID that exposed the issue, (c) the implementations that fail, and (d) proposed wording. The suite exists to make (b) and (c) easy.

## Adding coverage

If you find a clause that has no requirement, or a requirement that has no test, the contribution flow is:

1. **Open an issue** describing the gap. Include the clause URN.
2. **Propose requirement language** — a single sentence with a testable assertion. Use the existing `requirements/8601-{1,2}/*.yaml` style as a template.
3. **Propose one or more conformance tests** targeting the new requirement. Each test has a `given:` input and an `expect:` outcome.
4. **Submit a PR** with the new YAML. CI runs `ruby scripts/validate` and the full corpus against every adapter, so the new test will immediately show which implementations pass and fail.

See [For contributors](/docs/contributors) for the mechanics; this section is about *what* to add, not how.

## Periodic review

The suite is most useful to standards authors when reviewed on a regular cadence — typically once per WG meeting. The recommended pre-meeting checklist:

1. Re-run `ruby scripts/capability-matrix` to refresh the dashboard.
2. Open the matrix view, filter by category, and scan for new red columns.
3. Compare against the previous meeting's snapshot (commit log of `site/public/summary.json`).
4. For each new failure cluster, trace to a clause URN and decide: standard ambiguous, standard correct but implementations lagging, or test wrong.
5. Bring the top three to the WG as discussion items.

## Where to go next

- [The conformance model](/docs/conformance-model) — declared vs. not-declared semantics, end-to-end.
- [The identifier scheme](/docs/identifier-scheme) — RFC 5141 URN expansion for clause references.
- [For profile authors](/docs/profile-authors) — if your work extends to profile-level definitions (W3C, IETF, EDTF).
- [For contributors](/docs/contributors) — the mechanics of adding a test or requirement.
