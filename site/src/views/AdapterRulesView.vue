<script setup>
const emit = defineEmits(["navigate"]);

const tier1 = [
  {
    n: "1.1",
    title: "Documented format patterns",
    summary: "strptime / strftime / get_time with any number of documented format strings.",
    detail: "Any format the library documents as supported is fair game. Trying many format strings to dispatch on input shape is exactly what real-world code does — the adapter may do the same.",
    codeLang: "ruby",
    code: `# Ruby Date/Time/DateTime strptime is a documented library API.
# Each format string is a documented pattern.
STRPTIME_FORMATS = [
  [/\\A\\d{4}\\d{2}\\d{2}T\\d{2}\\d{2}\\d{2}[.,]\\d+Z\\z/,   "%Y%m%dT%H%M%S.%L%z", Time],
  [/\\A\\d{4}\\d{2}\\d{2}T\\d{2}\\d{2}\\d{2}[+-]\\d{2}:?\\d{2}\\z/, "%Y%m%dT%H%M%S%z", Time],
  # ...as many as needed; each a real library pattern...
]`
  },
  {
    n: "1.2",
    title: "Distinct library API entry points",
    summary: "LocalDate.parse + LocalDateTime.parse + OffsetDateTime.parse.",
    detail: "Calling multiple library parsers, each with that parser's default ISO 8601 format. Each is a real library function that real application code calls.",
    codeLang: "java",
    code: `try { return ParseResult.ok(store(OffsetDateTime.parse(expr)), ...); }
catch (DateTimeParseException ignored) {}
try { return ParseResult.ok(store(LocalDateTime.parse(expr)), ...); }
catch (DateTimeParseException ignored) {}
try { return ParseResult.ok(store(LocalDate.parse(expr)), ...); }
catch (DateTimeParseException ignored) {}`
  },
  {
    n: "1.3",
    title: "Hand-rolled generation from library-provided components",
    summary: "snprintf, sprintf, f-strings, template literals — when the data comes from the library.",
    detail: "The library may simply lack a format string for the target output. The adapter is serializing data the library already produced; no information is fabricated.",
    codeLang: "python",
    code: `# datetime.isoformat() can't produce basic format, but the library
# has all the data; the adapter just composes the string.
def _generate_datetime(year, month, day, time_comp, fmt):
    if fmt == "basic":
        return f"{year:04d}{month:02d}{day:02d}T{hour:02d}:{minute:02d}:{second:02d}"`
  },
  {
    n: "1.4",
    title: "Plumbing",
    summary: "JSON I/O, handle caches, metadata, dispatch loops, protocol framing.",
    detail: "Anything that doesn't touch ISO 8601 semantics at all — cache maintenance, line-buffered JSON protocol, harness plumbing — is by definition not gaming."
  }
];

const tier2 = [
  {
    n: "2.1",
    title: "Input pre-processing",
    bad: "Z → +00:00, comma → dot, strip signed-year prefix, strip trailing offset.",
    detail: "Editing the expression string before handing it to the library, to work around a documented library limitation. The library IS still parsing the input; the adapter is just spelling it the way the library expects.",
    codeLang: "python",
    code: `# strptime %z doesn't accept Z on older Pythons.
# The library IS still parsing the offset; we're just
# spelling it the way %z expects.
normalized = expr[:-1] + "+0000" if expr.endswith("Z") else expr
parsed = datetime.strptime(normalized, fmt)`,
    note: "Adapter MUST declare: \"strptime %z rejects Z on this runtime; adapter substitutes Z → +00:00 before parsing.\""
  },
  {
    n: "2.2",
    title: "Output post-processing",
    bad: "Recover wall-clock after UTC conversion; reconstruct offset the library collapsed.",
    detail: "Editing or reconstructing fields after a successful parse. The library parsed the input correctly; the adapter restores info the library chose to discard.",
    codeLang: "javascript",
    code: `// Date.parse accepts the input but converts to UTC, losing
// the original wall-clock. The offset is right there in the
// string; the adapter restores what Date.parse threw away.
const offsetMs = (tz.sign === "-" ? -1 : 1) * (tz.hours * 60 + tz.minutes) * 60000;
const adjusted = new Date(obj.getTime() + offsetMs);
hour = adjusted.getUTCHours();`,
    note: "Adapter MUST declare: \"Date.parse converts to UTC and discards original wall-clock; adapter re-applies the parsed offset to recover hour/minute/second.\""
  }
];

const tier3 = [
  {
    n: "3.1",
    title: "Inventing domain types",
    bad: "Library has no type for a feature (century, decade, fractional minute, expanded year); adapter declares its own model class.",
    detail: "If the library has no type for a feature, the adapter returns not-supported. It must not declare its own model classes (ReducedPrecisionDate, FractionalTime, FractionalMeta) to fabricate support.",
    codeLang: "java",
    badCode: `// Library (java.time) has no ReducedPrecisionDate type.
// Fabricating one makes "century" tests pass for a library
// that doesn't support centuries.
if (core.matches("^[0-9]{2}$")) {
    return ParseResult.ok(
        store(new ReducedPrecisionDate("century", Integer.parseInt(core))),
        "reduced-precision");
}`,
    goodCode: `// Century / decade inputs: java.time has no native representation.
return ParseResult.fail("java.time");  // → not-supported from harness`,
    offenders: ["Ruby ReducedPrecisionDate", "Java ReducedPrecisionDate + FractionalTime + FractionalMeta", "C++ CacheEntry::REDUCED"]
  },
  {
    n: "3.2",
    title: "Manually parsing components the library didn't produce",
    bad: "ISO week + ordinal day-of-year + day-of-week computed from y/m/d when the library object has no such fields.",
    detail: "extract_components returns ONLY fields the library's parsed object actually exposes. Computing derived fields from year/month/day and presenting them as if the library had produced them is the canonical case of \"the adapter is doing the work instead of the library\".",
    codeLang: "javascript",
    badCode: `// Date has no ISO week API. Computing one from y/m/d makes
// "Date supports week dates" appear true on the dashboard.
const wd = new Date(Date.UTC(year, month - 1, day));
const dayNum = wd.getUTCDay() || 7;
wd.setUTCDate(wd.getUTCDate() + 4 - dayNum);
const yearStart = new Date(Date.UTC(wd.getUTCFullYear(), 0, 1));
const weekNum = Math.ceil(((wd - yearStart) / 86400000 + 1) / 7);
result.week = { week_year: wd.getUTCFullYear(), week: weekNum, day_of_week: dayNum };`,
    goodCode: `// Return only fields Date actually exposes; omit "week".
const result = { calendar: { year, month, day } };
// No "week" key — Date has no week-date API.
return result;`,
    offenders: ["Node.js extractComponents (ordinal + week from scratch)", "C++ extract_components (iso_week, day_of_year, yday_to_md hand-rolled)"]
  },
  {
    n: "3.3",
    title: "Re-validation after acceptance",
    bad: "Library accepted Feb 30 / hour 25 / month 13; adapter re-checks validity the library skipped.",
    detail: "If the library's parser accepted invalid input, the adapter reports the parsed result as-is. The adapter MUST NOT run its own days-in-month / leap-year / range checks on a value the library already accepted. \"Does this library reject Feb 30?\" is itself a test question.",
    codeLang: "cpp",
    badCode: `// get_time silently accepts Feb 30. Adding our own
// days-in-month check makes the test pass for the wrong reason
// (adapter validation, not library validation).
static bool validate_tm(const std::tm& t, ...) {
  static const int days_in_month[] = {31,28,31,30,31,30,31,31,30,31,30,31};
  if (t.tm_mday > days_in_month[t.tm_mon]) return false;
}`,
    goodCode: `// Trust the library's parse. If get_time rolled Feb 30 over
// to Mar 2, the round-trip / component-match test will catch
// that downstream.
return ParseResult{true, store(t, ...), "", "get_time"};`,
    offenders: ["C++ validate_tm (days-in-month + leap-year checks)", "C++ validate_input_for_pattern (literal-character checks)"]
  }
];
</script>

<template>
  <div class="max-w-[1100px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">Adapter Rules</span>
    </div>

    <!-- Hero -->
    <section class="relative mb-12 pb-8 border-b border-rule">
      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 00</span>
          <span class="clause-label">Preventing test gaming</span>
        </div>
        <h1 class="display-hero text-4xl md:text-6xl mb-4">
          Adapter <em>purity</em> rules.
        </h1>
        <p class="text-ink-soft text-base md:text-lg max-w-2xl leading-relaxed">
          An adapter's only job is to translate between the JSON protocol and the
          library's native public API. Three tiers cover everything an adapter
          may do — <strong class="text-ink">Native</strong>,
          <strong class="text-ink">Qualification note</strong>, and
          <strong class="text-ink">Prohibited</strong>.
        </p>
      </div>
    </section>

    <!-- The Golden Rule -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">The Golden Rule</h2>
      </div>
      <div class="surface p-6">
        <p class="text-ink-soft text-base leading-relaxed mb-4">
          The point of this test suite is to <strong class="text-ink">measure where
          real libraries fall short of ISO 8601</strong>. An adapter that quietly
          fills those gaps itself destroys the signal and makes the dashboard lie.
        </p>
        <div class="surface-2 p-5 mt-4">
          <div class="clause-label mb-3">The one test for whether adapter behavior is gaming</div>
          <p class="font-display text-xl text-ink leading-relaxed">
            For this line of code — is the LIBRARY doing the work, or am I doing
            the work instead of the library?
          </p>
        </div>
        <p class="text-ink-soft text-base leading-relaxed mt-5">
          Three tiers fall out naturally from that question. If the library
          cannot do what a test asks for, the correct adapter response is
          <code class="font-mono text-steel">not-supported</code> — not
          <code class="font-mono text-jade">pass</code>, and not
          <code class="font-mono text-rust">fail</code>-with-massaged-output.
        </p>
      </div>
    </section>

    <!-- Tier 1 — Native -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 02</span>
        <h2 class="section-title">Tier 1 — Native</h2>
        <span class="clause-label text-jade ml-auto">No declaration needed</span>
      </div>
      <p class="text-sm text-ink-muted leading-relaxed mb-5">
        The library is doing the work via its documented public API. The adapter
        configures it and reports the result.
      </p>

      <div class="space-y-4">
        <article v-for="p in tier1" :key="p.n" class="surface p-5">
          <div class="flex items-baseline gap-3 mb-2">
            <span class="clause-label text-jade">§ {{ p.n }}</span>
            <h3 class="font-display text-xl text-ink">{{ p.title }}</h3>
          </div>
          <p class="font-mono text-xs text-steel mb-3">{{ p.summary }}</p>
          <p class="text-sm text-ink-soft leading-relaxed mb-4">{{ p.detail }}</p>
          <div v-if="p.code" class="bg-ink-900 text-ink-100 dark:bg-black/40 dark:text-ink-200 rounded-md p-4 mt-3 overflow-x-auto">
            <div class="clause-label text-jade/80 mb-2">✓ NATIVE — {{ p.codeLang }}</div>
            <pre class="font-mono text-xs leading-relaxed whitespace-pre"><code>{{ p.code }}</code></pre>
          </div>
        </article>
      </div>
    </section>

    <!-- Tier 2 — Qualification notes -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 03</span>
        <h2 class="section-title">Tier 2 — Qualification notes</h2>
        <span class="clause-label text-accent ml-auto">Must be declared</span>
      </div>
      <p class="text-sm text-ink-muted leading-relaxed mb-5">
        The library is doing the work, but the adapter performs minor edits to
        the input before the call or to the output after. These edits work around
        known library quirks; the library is still the parser/formatter. The
        behavior is acceptable, <strong class="text-ink">but the adapter MUST
        declare a qualification note</strong> so the dashboard can surface it.
      </p>

      <div class="space-y-4">
        <article v-for="p in tier2" :key="p.n" class="surface p-5">
          <div class="flex items-baseline gap-3 mb-2">
            <span class="clause-label text-accent">§ {{ p.n }}</span>
            <h3 class="font-display text-xl text-ink">{{ p.title }}</h3>
          </div>
          <p class="font-mono text-xs text-accent mb-3">{{ p.bad }}</p>
          <p class="text-sm text-ink-soft leading-relaxed mb-4">{{ p.detail }}</p>
          <div class="bg-ink-900 text-ink-100 dark:bg-black/40 dark:text-ink-200 rounded-md p-4 mt-3 overflow-x-auto">
            <div class="clause-label text-accent/80 mb-2">⚠ QUALIFICATION NOTE — {{ p.codeLang }}</div>
            <pre class="font-mono text-xs leading-relaxed whitespace-pre"><code>{{ p.code }}</code></pre>
          </div>
          <div class="surface-2 p-3 mt-3 border-l-2 border-accent">
            <div class="clause-label text-accent mb-1">Required declaration</div>
            <p class="font-mono text-xs text-ink-soft leading-relaxed">{{ p.note }}</p>
          </div>
        </article>
      </div>
    </section>

    <!-- Tier 3 — Prohibited -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 04</span>
        <h2 class="section-title">Tier 3 — Prohibited</h2>
        <span class="clause-label text-rust ml-auto">Test gaming — return not-supported</span>
      </div>
      <p class="text-sm text-ink-muted leading-relaxed mb-5">
        The adapter is doing the work instead of the library. These patterns
        must be removed when found, and must not be re-introduced. Each appears
        with a concrete NOT ACCEPTABLE example and its ACCEPTABLE replacement.
      </p>

      <div class="space-y-5">
        <article v-for="p in tier3" :key="p.n" class="surface p-5">
          <div class="flex items-baseline gap-3 mb-2">
            <span class="clause-label text-rust">§ {{ p.n }}</span>
            <h3 class="font-display text-xl text-ink">{{ p.title }}</h3>
          </div>
          <p class="font-mono text-xs text-rust mb-3">{{ p.bad }}</p>
          <p class="text-sm text-ink-soft leading-relaxed mb-4">{{ p.detail }}</p>

          <div v-if="p.badCode" class="grid md:grid-cols-2 gap-3 mt-4">
            <div class="bg-ink-900 text-ink-100 dark:bg-black/40 dark:text-ink-200 rounded-md p-4 overflow-x-auto">
              <div class="clause-label text-rust mb-2">✗ PROHIBITED — {{ p.codeLang }}</div>
              <pre class="font-mono text-xs leading-relaxed whitespace-pre"><code>{{ p.badCode }}</code></pre>
            </div>
            <div class="bg-ink-900 text-ink-100 dark:bg-black/40 dark:text-ink-200 rounded-md p-4 overflow-x-auto">
              <div class="clause-label text-jade mb-2">✓ Return not-supported</div>
              <pre class="font-mono text-xs leading-relaxed whitespace-pre"><code>{{ p.goodCode }}</code></pre>
            </div>
          </div>

          <div class="mt-4">
            <div class="clause-label mb-1.5">Historical offenders</div>
            <ul class="space-y-1 text-xs text-ink-muted list-none">
              <li v-for="o in p.offenders" :key="o" class="flex gap-2">
                <span class="text-rust">·</span>
                <span class="font-mono text-steel">{{ o }}</span>
              </li>
            </ul>
          </div>
        </article>
      </div>
    </section>

    <!-- One-line test -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 05</span>
        <h2 class="section-title">The one-line test</h2>
      </div>
      <div class="surface p-6">
        <div class="surface-2 p-5 mb-4">
          <p class="font-display text-lg text-ink leading-relaxed">
            Is the library doing the work here? If yes — native, or qualification
            note if I edited the I/O. If no — delete the line and return
            <code class="font-mono text-steel">not-supported</code>.
          </p>
        </div>
        <div class="overflow-hidden">
          <table class="editorial">
            <thead>
              <tr><th>Tier</th><th>One-line test</th></tr>
            </thead>
            <tbody>
              <tr>
                <td><span class="clause-label text-jade">1 — Native</span></td>
                <td>The library is doing the work; the adapter configures it.</td>
              </tr>
              <tr>
                <td><span class="clause-label text-accent">2 — Qualification</span></td>
                <td>The library is doing the work; the adapter edits input or output around it. Declare the workaround.</td>
              </tr>
              <tr>
                <td><span class="clause-label text-rust">3 — Prohibited</span></td>
                <td>The adapter is doing the work instead of the library. Stop. Return not-supported.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>

    <!-- Port upstream -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 06</span>
        <h2 class="section-title">A note to library authors: port your wrappers upstream</h2>
      </div>
      <div class="surface p-6">
        <p class="text-ink-soft text-base leading-relaxed mb-4">
          If you find yourself writing a wrapper, a workaround, or a qualification
          note in an adapter — <strong class="text-ink">the more effective and
          easier long-term fix is to fix the underlying library</strong>, not the
          adapter.
        </p>
        <p class="text-ink-soft text-base leading-relaxed mb-4">
          The wrapper code you're tempted to write inside an adapter is almost
          always exactly the code that belongs inside the library itself. The
          library is what real users call; the library is what real applications
          depend on. A wrapper that lives only inside this test-suite adapter
          helps nobody but the dashboard number. A wrapper ported into the library
          helps every user of that library, on every project, forever.
        </p>

        <div class="surface-2 p-5 mt-5 mb-5">
          <div class="clause-label mb-3">Concretely</div>
          <ul class="space-y-2.5 text-sm text-ink-soft list-none">
            <li class="flex gap-3">
              <span class="text-accent shrink-0">→</span>
              <span><strong class="text-ink">Tier 2 workarounds are library bug reports waiting to be filed.</strong> If Python <code class="font-mono text-steel">strptime %z</code> rejects <code class="font-mono text-steel">Z</code>, that's a CPython bug — file it, fix it, submit a PR.</span>
            </li>
            <li class="flex gap-3">
              <span class="text-accent shrink-0">→</span>
              <span><strong class="text-ink">Tier 3 fabrication is usually a library missing a feature.</strong> If <code class="font-mono text-steel">java.time</code> has no century type, the right fix is to add one upstream, not to invent <code class="font-mono text-steel">ReducedPrecisionDate</code> inside a test adapter.</span>
            </li>
            <li class="flex gap-3">
              <span class="text-accent shrink-0">→</span>
              <span><strong class="text-ink">The dashboard is the backlog; the libraries are the work.</strong> Every <code class="font-mono text-steel">not-supported</code> and every qualification note is a candidate upstream PR.</span>
            </li>
          </ul>
        </div>

        <div class="grid md:grid-cols-2 gap-4 mt-5">
          <div class="surface-2 p-4">
            <div class="clause-label text-rust mb-2">Why adapter fixes are temporary</div>
            <ul class="space-y-1.5 text-xs text-ink-muted list-none">
              <li class="flex gap-2"><span class="text-rust">·</span>A wrapper in an adapter rots the moment the adapter is no longer maintained.</li>
              <li class="flex gap-2"><span class="text-rust">·</span>An adapter fix helps only the conformance report — real apps call the library directly.</li>
            </ul>
          </div>
          <div class="surface-2 p-4">
            <div class="clause-label text-jade mb-2">Why library fixes are permanent</div>
            <ul class="space-y-1.5 text-xs text-ink-muted list-none">
              <li class="flex gap-2"><span class="text-jade">·</span>A fix in the library ships with every release of the library.</li>
              <li class="flex gap-2"><span class="text-jade">·</span>Most workarounds are 10-line patches — comparable work to port.</li>
            </ul>
          </div>
        </div>

        <p class="text-ink-soft text-base leading-relaxed mt-5">
          The end goal of this test suite is not "every adapter reports 100%
          pass" — that goal would be meaningless, because the adapters could
          always lie. The end goal is "every library implements ISO 8601
          correctly, and the dashboard reflects that without any adapter-side
          workarounds at all."
        </p>
      </div>
    </section>

    <!-- Audit history -->
    <section>
      <div class="section-header">
        <span class="section-number">§ 07</span>
        <h2 class="section-title">Audit history</h2>
      </div>
      <div class="surface p-6 space-y-4">
        <div class="flex items-start gap-4">
          <span class="font-mono text-xs text-ink-muted shrink-0 w-24 tabular-nums">2026-06-24</span>
          <p class="text-sm text-ink-soft leading-relaxed">
            Initial audit. All seven adapter families (Ruby, Python, Node, C,
            C++, Rust, Java) were found to violate at least one Tier 3 pattern.
            Cleanup tracked separately per adapter.
          </p>
        </div>
        <div class="flex items-start gap-4">
          <span class="font-mono text-xs text-ink-muted shrink-0 w-24 tabular-nums">2026-06-24</span>
          <p class="text-sm text-ink-soft leading-relaxed">
            Three-tier framework adopted. Many patterns previously classified as
            prohibited (format cascades, hand-rolled generation, wall-clock
            reconstruction, input rewriting) are reclassified: format cascades
            and hand-rolled generation are Tier 1; input rewriting and wall-clock
            reconstruction are Tier 2 with required qualification notes. Only
            invented domain types, fabricated components, and re-validation
            remain prohibited.
          </p>
        </div>
      </div>
      <p class="text-sm text-ink-muted leading-relaxed mt-5">
        The authoritative rules document lives at
        <code class="font-mono text-steel">adapters/RULES.adoc</code>
        in the repository.
      </p>
    </section>
  </div>
</template>
