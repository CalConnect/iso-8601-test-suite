<script setup>
const emit = defineEmits(["navigate"]);
</script>

<template>
  <div class="max-w-[1100px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">Developer Guide</span>
    </div>

    <!-- Hero -->
    <section class="relative mb-12 pb-8 border-b border-rule">
      <div class="iso-watermark hidden md:block">
        <span style="top: 20%; left: 12%;">adapters/*.yaml</span>
        <span style="top: 58%; right: 14%;">exec:python3</span>
        <span style="top: 78%; left: 40%;">profiles/TEMPLATE</span>
      </div>
      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 00</span>
          <span class="clause-label">For implementers</span>
        </div>
        <h1 class="display-hero text-4xl md:text-6xl mb-4">
          Developer <em>guide</em>.
        </h1>
        <p class="text-ink-soft text-base md:text-lg max-w-2xl leading-relaxed">
          Test your date/time library against the suite, author a new adapter in any language,
          or define a domain-specific profile.
        </p>
      </div>
    </section>

    <!-- Quick start -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">Quick start — five minutes to first result</h2>
      </div>
      <div class="surface p-6">
        <p class="text-ink-soft text-base leading-relaxed mb-4">
          The test suite uses a <strong class="text-ink">pluggable adapter</strong> architecture.
          Your library doesn't need to be written in Ruby — the harness communicates with
          any process via a simple JSON protocol.
        </p>
        <ol class="space-y-2 mb-5 font-display text-lg text-ink list-none">
          <li class="flex gap-3"><span class="clause-label-accent tabular-nums w-6 shrink-0">01</span> Copy the adapter template for your language</li>
          <li class="flex gap-3"><span class="clause-label-accent tabular-nums w-6 shrink-0">02</span> Implement four methods: parse, extract, generate, equivalent</li>
          <li class="flex gap-3"><span class="clause-label-accent tabular-nums w-6 shrink-0">03</span> Run the test suite against your adapter</li>
        </ol>
        <div class="surface-2 p-4 font-mono text-xs space-y-3">
          <div>
            <div class="clause-label mb-1">Python</div>
            <div class="text-steel">ruby scripts/run-tests --adapter "exec:python3 adapters/python-datetime.py"</div>
          </div>
          <div>
            <div class="clause-label mb-1">Node.js</div>
            <div class="text-steel">ruby scripts/run-tests --adapter "exec:node adapters/node-datetime.js"</div>
          </div>
          <div>
            <div class="clause-label mb-1">Any executable</div>
            <div class="text-steel">ruby scripts/run-tests --adapter "exec:./adapters/my-rust-binary"</div>
          </div>
        </div>
      </div>
    </section>

    <!-- Adapter interface -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 02</span>
        <h2 class="section-title">Adapter interface</h2>
      </div>
      <div class="surface p-6">
        <p class="text-ink-soft text-base leading-relaxed mb-5">
          Each adapter implements a well-defined interface. The test harness calls these methods
          based on the test type.
        </p>
        <div class="surface overflow-hidden mb-5">
          <table class="editorial">
            <thead>
              <tr>
                <th>Method</th>
                <th>Used by</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="font-mono text-steel">try_parse(expr, options)</td>
                <td>validity, parsing, round_trip, equivalence</td>
              </tr>
              <tr>
                <td class="font-mono text-steel">extract_components(parsed)</td>
                <td>parsing, round_trip</td>
              </tr>
              <tr>
                <td class="font-mono text-steel">generate(components)</td>
                <td>generation, round_trip</td>
              </tr>
              <tr>
                <td class="font-mono text-steel">equivalent?(a, b)</td>
                <td>equivalence</td>
              </tr>
              <tr>
                <td class="font-mono text-steel">run_arithmetic(test)</td>
                <td>arithmetic (optional)</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div>
          <div class="clause-label mb-2">Parsing modes</div>
          <p class="text-sm text-ink-muted mb-3">
            <code class="font-mono text-steel">try_parse</code> accepts an
            <code class="font-mono text-steel">options</code> hash with a
            <code class="font-mono text-steel">parse_mode</code> field:
          </p>
          <ul class="space-y-1.5 text-sm text-ink-soft list-none">
            <li class="flex gap-2"><span class="text-accent">·</span> <strong class="text-ink">dedicated</strong> (default) — format-specific parser (e.g. strptime with explicit format)</li>
            <li class="flex gap-2"><span class="text-accent">·</span> <strong class="text-ink">undifferentiated</strong> — general/lenient parser (e.g. Date.parse, fromisoformat)</li>
          </ul>
        </div>
      </div>
    </section>

    <!-- JSON protocol -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 03</span>
        <h2 class="section-title">JSON protocol for non-Ruby implementations</h2>
      </div>
      <div class="surface p-6">
        <p class="text-ink-soft text-base leading-relaxed mb-5">
          The harness starts your adapter as a child process. For each test, it writes
          one JSON command to stdin and reads one JSON response from stdout — each on a single line.
        </p>
        <div class="surface-2 p-4 font-mono text-xs space-y-3">
          <div>
            <div class="clause-label mb-1">Request</div>
            <div class="text-steel">{"method":"try_parse","params":{"expression":"1985-04-12","options":{"parse_mode":"dedicated"}}}</div>
          </div>
          <div>
            <div class="clause-label mb-1">Response (success)</div>
            <div class="text-jade">{"result":{"valid":true,"parsed":"h1","api":"Date.strptime"}}</div>
          </div>
          <div>
            <div class="clause-label mb-1">Response (failure)</div>
            <div class="text-rust">{"result":{"valid":false,"error":"invalid date","api":"Date.strptime"}}</div>
          </div>
        </div>
        <p class="text-sm text-ink-muted leading-relaxed mt-5">
          The <code class="font-mono text-steel">parsed</code> value is an opaque handle — your adapter caches the
          internal parsed object and returns a string key. The harness passes this key back
          to <code class="font-mono text-steel">extract_components</code> and
          <code class="font-mono text-steel">equivalent</code>.
        </p>
        <p class="text-sm text-ink-muted leading-relaxed mt-3">
          See <code class="font-mono text-steel">adapters/python-datetime.py</code> and
          <code class="font-mono text-steel">adapters/node-datetime.js</code> for working examples.
        </p>
      </div>
    </section>

    <!-- Test types -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 04</span>
        <h2 class="section-title">Test types</h2>
      </div>
      <div class="surface divide-y divide-rule-soft">
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="clause-label w-24 shrink-0 pt-0.5">Parsing</span>
          <span class="text-sm text-ink-soft">expression → components. Parse a string and validate that extracted components (year, month, day, etc.) match expectations.</span>
        </div>
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="clause-label w-24 shrink-0 pt-0.5">Validity</span>
          <span class="text-sm text-ink-soft">expression → boolean. Check if a string is syntactically valid without extracting components.</span>
        </div>
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="clause-label w-24 shrink-0 pt-0.5">Generation</span>
          <span class="text-sm text-ink-soft">components → expression. Build an ISO 8601 string from structured components.</span>
        </div>
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="clause-label w-24 shrink-0 pt-0.5">Round-trip</span>
          <span class="text-sm text-ink-soft">expression → parse → extract → generate → compare. Verifies that parsing and generation are inverses.</span>
        </div>
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="clause-label w-24 shrink-0 pt-0.5">Equivalence</span>
          <span class="text-sm text-ink-soft">two expressions → boolean. Check if two expressions resolve to the same instant.</span>
        </div>
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="clause-label w-24 shrink-0 pt-0.5">Arithmetic</span>
          <span class="text-sm text-ink-soft">expression + operation → result. Date/time arithmetic (add, subtract).</span>
        </div>
      </div>
    </section>

    <!-- Creating a profile -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 05</span>
        <h2 class="section-title">Creating a new profile</h2>
      </div>
      <div class="surface p-6">
        <p class="text-ink-soft text-base leading-relaxed mb-5">
          If you're a standards body or community developing a subset of ISO 8601 for
          a specific domain, you can define a profile that selects specific requirements
          from the test suite.
        </p>
        <ol class="space-y-2 mb-5 font-display text-base text-ink list-none">
          <li class="flex gap-3"><span class="clause-label-accent tabular-nums w-6 shrink-0">01</span> Copy <code class="font-mono text-sm text-steel">profiles/TEMPLATE.yaml</code> to <code class="font-mono text-sm text-steel">profiles/{name}.yaml</code></li>
          <li class="flex gap-3"><span class="clause-label-accent tabular-nums w-6 shrink-0">02</span> Set <code class="font-mono text-sm text-steel">id</code>, <code class="font-mono text-sm text-steel">name</code>, <code class="font-mono text-sm text-steel">description</code></li>
          <li class="flex gap-3"><span class="clause-label-accent tabular-nums w-6 shrink-0">03</span> Define <code class="font-mono text-sm text-steel">traceability</code> — list specific requirements from each conformance class</li>
          <li class="flex gap-3"><span class="clause-label-accent tabular-nums w-6 shrink-0">04</span> Optionally add <code class="font-mono text-sm text-steel">additional_requirements</code> and <code class="font-mono text-sm text-steel">additional_tests</code></li>
          <li class="flex gap-3"><span class="clause-label-accent tabular-nums w-6 shrink-0">05</span> Validate: <code class="font-mono text-sm text-steel">ruby scripts/validate</code></li>
          <li class="flex gap-3"><span class="clause-label-accent tabular-nums w-6 shrink-0">06</span> Test: <code class="font-mono text-sm text-steel">ruby scripts/run-tests --profile {name}</code></li>
        </ol>
        <p class="text-sm text-ink-muted">
          Available requirement IDs are defined in
          <code class="font-mono text-xs text-steel">requirements/8601-1/*.yaml</code>
          and <code class="font-mono text-xs text-steel">requirements/8601-2/*.yaml</code>.
        </p>
      </div>
    </section>

    <!-- Understanding results -->
    <section>
      <div class="section-header">
        <span class="section-number">§ 06</span>
        <h2 class="section-title">Understanding results</h2>
      </div>
      <div class="surface divide-y divide-rule-soft">
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="pill pill-pass w-24 shrink-0 justify-center">PASS</span>
          <span class="text-sm text-ink-soft pt-0.5">The implementation produced the expected result.</span>
        </div>
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="pill pill-partial w-24 shrink-0 justify-center">PARTIAL</span>
          <span class="text-sm text-ink-soft pt-0.5">Some tests for this requirement passed, but not all.</span>
        </div>
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="pill pill-fail w-24 shrink-0 justify-center">FAIL</span>
          <span class="text-sm text-ink-soft pt-0.5">The implementation did not produce the expected result.</span>
        </div>
        <div class="px-5 py-3.5 flex items-start gap-4">
          <span class="pill pill-muted w-24 shrink-0 justify-center">N/S</span>
          <span class="text-sm text-ink-soft pt-0.5">The implementation does not support this feature (not counted as failure).</span>
        </div>
      </div>
      <p class="text-sm text-ink-muted leading-relaxed mt-5 max-w-3xl">
        A library can declare which conformance classes it targets. Tests in undeclared
        classes are marked <strong class="text-ink-soft">not-supported</strong> rather than
        <strong class="text-ink-soft">fail</strong>, reflecting that the library intentionally
        doesn't support that feature.
      </p>
    </section>
  </div>
</template>
