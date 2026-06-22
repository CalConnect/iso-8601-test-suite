<script setup>
const emit = defineEmits(["navigate"]);
</script>

<template>
  <div class="max-w-[1100px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">Methodology</span>
    </div>

    <!-- Hero -->
    <section class="relative mb-12 pb-8 border-b border-rule">
      <div class="iso-watermark hidden md:block">
        <span style="top: 18%; left: 12%;">test_type:parsing</span>
        <span style="top: 64%; right: 16%;">round_trip</span>
        <span style="top: 82%; left: 38%;">extract · generate</span>
      </div>
      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 00</span>
          <span class="clause-label">How conformance is measured</span>
        </div>
        <h1 class="display-hero text-4xl md:text-6xl mb-4">
          Test <em>methodology</em>.
        </h1>
        <p class="text-ink-soft text-base md:text-lg max-w-2xl leading-relaxed">
          The ISO 8601 conformance test suite verifies implementations through five
          distinct testing approaches. Each approach tests a distinct capability
          of a conformant date/time processor.
        </p>
      </div>
    </section>

    <!-- Approach overview -->
    <section class="mb-14">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">Approaches at a glance</h2>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div class="surface p-5">
          <div class="flex items-baseline gap-2 mb-3">
            <span class="w-1 h-5 bg-accent"></span>
            <h3 class="font-display text-base text-ink">Parsing</h3>
          </div>
          <p class="text-sm text-ink-muted leading-relaxed">Can the implementation recognize and interpret ISO 8601 expressions?</p>
          <div class="clause-label mt-4">Two sub-types</div>
        </div>
        <div class="surface p-5">
          <div class="flex items-baseline gap-2 mb-3">
            <span class="w-1 h-5 bg-jade"></span>
            <h3 class="font-display text-base text-ink">Generation</h3>
          </div>
          <p class="text-sm text-ink-muted leading-relaxed">Can the implementation produce correct ISO 8601 expressions from structured data?</p>
          <div class="clause-label mt-4">Components → Expression</div>
        </div>
        <div class="surface p-5">
          <div class="flex items-baseline gap-2 mb-3">
            <span class="w-1 h-5 bg-amber"></span>
            <h3 class="font-display text-base text-ink">Round-trip</h3>
          </div>
          <p class="text-sm text-ink-muted leading-relaxed">Does the full pipeline preserve semantic equivalence?</p>
          <div class="clause-label mt-4">Parse → Extract → Generate</div>
        </div>
      </div>
    </section>

    <!-- Detailed sections -->
    <section class="space-y-14">

      <!-- 1. Parsing -->
      <div>
        <div class="section-header">
          <span class="section-number">§ 02</span>
          <h2 class="section-title">Parsing tests</h2>
        </div>
        <p class="text-ink-soft text-base leading-relaxed mb-6 max-w-3xl">
          Parsing tests verify that an implementation can correctly recognize and
          interpret ISO 8601 expressions. The test suite distinguishes two
          <strong class="text-ink">parsing modes</strong> to test different
          aspects of an implementation's parsing capability.
        </p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div class="surface p-5">
            <div class="flex items-center gap-2 mb-3">
              <span class="micro-tag">dedicated</span>
              <h3 class="font-display text-base text-ink">Dedicated Format Parsing</h3>
            </div>
            <p class="text-sm text-ink-muted leading-relaxed mb-4">
              Uses a <strong class="text-ink-soft">format-specific parser</strong>
              that explicitly targets a particular ISO 8601 format pattern. The
              parser is given a format string matching the exact pattern described
              in the requirement.
            </p>
            <div class="surface-2 p-3 font-mono text-xs space-y-1">
              <div class="text-ink-faint"># parsing basic format YYYYMMDD</div>
              <div><span class="text-steel">strptime</span>(<span class="text-ink">"19850412"</span>, <span class="text-jade">"%Y%m%d"</span>)</div>
            </div>
            <p class="text-xs text-ink-faint mt-4">
              <strong class="text-ink-muted">When to use:</strong> When the test
              targets a specific ISO 8601 format. This is the <strong class="text-ink-soft">default</strong>
              parsing mode.
            </p>
          </div>

          <div class="surface p-5">
            <div class="flex items-center gap-2 mb-3">
              <span class="micro-tag">undifferentiated</span>
              <h3 class="font-display text-base text-ink">Undifferentiated Parsing</h3>
            </div>
            <p class="text-sm text-ink-muted leading-relaxed mb-4">
              Uses a <strong class="text-ink-soft">general-purpose, format-agnostic
              parser</strong> that may accept multiple ISO 8601 format variants
              without being told which format to expect.
            </p>
            <div class="surface-2 p-3 font-mono text-xs space-y-1">
              <div class="text-ink-faint"># general parser infers format</div>
              <div><span class="text-steel">Date</span>.<span class="text-jade">parse</span>(<span class="text-ink">"1985-04-12"</span>)</div>
            </div>
            <p class="text-xs text-ink-faint mt-4">
              <strong class="text-ink-muted">When to use:</strong> Testing whether
              a general-purpose parser correctly accepts or rejects an expression.
            </p>
          </div>
        </div>
      </div>

      <!-- 2. Generation -->
      <div>
        <div class="section-header">
          <span class="section-number">§ 03</span>
          <h2 class="section-title">Generation tests</h2>
        </div>
        <p class="text-ink-soft text-base leading-relaxed mb-6 max-w-3xl">
          Generation tests verify that an implementation can produce the correct
          ISO 8601 expression string from structured date/time components. The
          test provides components and expects the implementation to serialize
          them into the exact format specified.
        </p>
        <div class="surface p-5">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 items-center text-sm">
            <div>
              <div class="clause-label mb-2">Input components</div>
              <code class="font-mono text-xs text-steel">{ calendar: { year: 1985, month: 4, day: 12 } }</code>
            </div>
            <div class="flex items-center justify-center">
              <svg class="w-6 h-6 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M13 7l5 5m0 0l-5 5m5-5H6"/></svg>
            </div>
            <div>
              <div class="clause-label mb-2">Expected expression</div>
              <code class="font-mono text-sm text-jade">"1985-04-12"</code>
            </div>
          </div>
        </div>
      </div>

      <!-- 3. Round-trip -->
      <div>
        <div class="section-header">
          <span class="section-number">§ 04</span>
          <h2 class="section-title">Round-trip tests</h2>
        </div>
        <p class="text-ink-soft text-base leading-relaxed mb-6 max-w-3xl">
          Round-trip tests exercise the full parsing-extraction-generation
          pipeline. An expression is parsed, its components are extracted, a new
          expression is generated, and the result is compared with the original.
        </p>
        <div class="surface p-5">
          <div class="clause-label mb-4">Pipeline</div>
          <div class="flex flex-wrap items-center gap-2 font-mono text-xs">
            <span class="border border-accent/30 text-accent px-2 py-1">"19850412"</span>
            <span class="text-ink-faint">→</span>
            <span class="surface-2 px-2 py-1 text-ink-muted">parse</span>
            <span class="text-ink-faint">→</span>
            <span class="surface-2 px-2 py-1 text-ink-muted">extract</span>
            <span class="text-ink-faint">→</span>
            <span class="surface-2 px-2 py-1 text-ink-muted">generate</span>
            <span class="text-ink-faint">→</span>
            <span class="border border-jade/30 text-jade px-2 py-1">"19850412"</span>
          </div>
        </div>
        <p class="text-sm text-ink-muted leading-relaxed mt-5 max-w-3xl">
          A round-trip test passes when the generated expression either matches
          the original exactly, or is <strong class="text-ink-soft">semantically equivalent</strong>
          (representing the same value in a different format, e.g. basic vs extended).
        </p>
      </div>

      <!-- Test type mapping -->
      <div>
        <div class="section-header">
          <span class="section-number">§ 05</span>
          <h2 class="section-title">Test types in YAML definitions</h2>
        </div>
        <p class="text-ink-soft text-base leading-relaxed mb-6 max-w-3xl">
          Each conformance test specifies a
          <code class="font-mono text-xs text-steel surface-2 px-1.5 py-0.5">test_type</code>
          field that maps to one of the approaches:
        </p>
        <div class="surface overflow-hidden">
          <table class="editorial">
            <thead>
              <tr>
                <th>test_type</th>
                <th>Approach</th>
                <th>Description</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="font-mono text-steel">parsing</td>
                <td class="text-accent">Parsing</td>
                <td>Parse expression, verify validity and extracted components</td>
              </tr>
              <tr>
                <td class="font-mono text-steel">validity</td>
                <td class="text-accent">Parsing</td>
                <td>Parse expression, verify only validity (no component extraction)</td>
              </tr>
              <tr>
                <td class="font-mono text-steel">generation</td>
                <td class="text-jade">Generation</td>
                <td>Generate expression from components, verify output string</td>
              </tr>
              <tr>
                <td class="font-mono text-steel">round_trip</td>
                <td class="text-amber">Round-trip</td>
                <td>Parse → extract → generate, verify equivalence</td>
              </tr>
              <tr>
                <td class="font-mono text-steel">equivalence</td>
                <td class="text-ink-soft">Equivalence</td>
                <td>Parse two expressions, verify they represent the same value</td>
              </tr>
              <tr>
                <td class="font-mono text-steel">arithmetic</td>
                <td class="text-rust">Arithmetic</td>
                <td>Perform date/time arithmetic operations</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="surface p-5 mt-5">
          <div class="clause-label mb-3">
            <code class="font-mono text-steel">parse_mode</code> field (parsing/validity tests only)
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div class="surface-2 p-3 font-mono text-xs">
              <code class="text-steel">parse_mode: dedicated</code>
              <span class="text-ink-faint ml-1">(default)</span>
              <p class="text-ink-muted mt-2 font-sans text-sm">Adapter uses format-specific parsing (e.g. strptime)</p>
            </div>
            <div class="surface-2 p-3 font-mono text-xs">
              <code class="text-steel">parse_mode: undifferentiated</code>
              <p class="text-ink-muted mt-2 font-sans text-sm">Adapter uses general/lenient parsing (e.g. Date.parse)</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
