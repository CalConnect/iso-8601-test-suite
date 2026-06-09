<script setup>
const emit = defineEmits(["navigate"]);
</script>

<template>
  <div class="max-w-[900px] mx-auto px-4 md:px-8 py-8">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 text-xs text-gray-500 mb-6">
      <button @click="emit('navigate', '/')" class="hover:text-gray-300 transition-colors">Dashboard</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="text-gray-400">Methodology</span>
    </div>

    <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight mb-2">
      Test <span class="text-[#e3000f]">Methodology</span>
    </h1>
    <p class="text-sm text-gray-400 mt-2 mb-8 max-w-2xl">
      The ISO 8601 conformance test suite verifies implementations through five
      distinct testing approaches. Each approach tests a distinct capability
      of a conformant date/time processor.
    </p>

    <!-- Approach overview cards -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-10">
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
        <div class="flex items-center gap-2 mb-2">
          <span class="w-1 h-5 bg-blue-500 rounded-full"></span>
          <h3 class="text-sm font-bold text-blue-400">Parsing</h3>
        </div>
        <p class="text-xs text-gray-400">Can the implementation recognize and interpret ISO 8601 expressions?</p>
        <div class="mt-3 text-[10px] text-gray-500 uppercase tracking-wider font-bold">Two sub-types</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
        <div class="flex items-center gap-2 mb-2">
          <span class="w-1 h-5 bg-emerald-500 rounded-full"></span>
          <h3 class="text-sm font-bold text-emerald-400">Generation</h3>
        </div>
        <p class="text-xs text-gray-400">Can the implementation produce correct ISO 8601 expressions from structured data?</p>
        <div class="mt-3 text-[10px] text-gray-500 uppercase tracking-wider font-bold">Components &rarr; Expression</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
        <div class="flex items-center gap-2 mb-2">
          <span class="w-1 h-5 bg-amber-500 rounded-full"></span>
          <h3 class="text-sm font-bold text-amber-400">Round-trip</h3>
        </div>
        <p class="text-xs text-gray-400">Does the full pipeline preserve semantic equivalence?</p>
        <div class="mt-3 text-[10px] text-gray-500 uppercase tracking-wider font-bold">Parse &rarr; Extract &rarr; Generate</div>
      </div>
    </div>

    <!-- Detailed sections -->
    <div class="space-y-8">

      <!-- 1. Parsing -->
      <section>
        <h2 class="text-lg font-bold mb-4 flex items-center gap-3">
          <span class="w-2 h-2 bg-blue-500 rounded-full"></span>
          1. Parsing Tests
        </h2>
        <p class="text-sm text-gray-400 leading-relaxed mb-5">
          Parsing tests verify that an implementation can correctly recognize and
          interpret ISO 8601 expressions. The test suite distinguishes two
          <strong class="text-gray-200">parsing modes</strong> to test different
          aspects of an implementation's parsing capability.
        </p>

        <!-- Dedicated Format -->
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5 mb-4">
          <h3 class="text-sm font-bold text-blue-400 mb-3 flex items-center gap-2">
            <span class="px-1.5 py-0.5 bg-blue-500/10 border border-blue-500/20 rounded text-[10px] font-mono">dedicated</span>
            Dedicated Format Parsing
          </h3>
          <p class="text-sm text-gray-400 leading-relaxed mb-4">
            Uses a <strong class="text-gray-200">format-specific parser</strong>
            that explicitly targets a particular ISO 8601 format pattern. The
            parser is given a format string matching the exact pattern described
            in the requirement, ensuring the implementation correctly handles
            that specific representation.
          </p>
          <div class="bg-gray-950/80 rounded-md p-4 text-xs font-mono text-gray-300 mb-4">
            <div class="text-gray-500 mb-1"># Example: parsing basic format YYYYMMDD</div>
            <div class="text-blue-400">strptime</div>("19850412", <span class="text-emerald-400">"%Y%m%d"</span>)
            <div class="text-gray-500 mt-1"># Format string exactly matches the requirement's pattern</div>
          </div>
          <p class="text-xs text-gray-500">
            <strong class="text-gray-400">When to use:</strong> When the test
            targets a specific ISO 8601 format (basic vs extended, specific
            precision level). This is the <strong class="text-gray-300">default</strong>
            parsing mode for all parsing and validity tests.
          </p>
        </div>

        <!-- Undifferentiated -->
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
          <h3 class="text-sm font-bold text-blue-400 mb-3 flex items-center gap-2">
            <span class="px-1.5 py-0.5 bg-blue-500/10 border border-blue-500/20 rounded text-[10px] font-mono">undifferentiated</span>
            Undifferentiated Parsing
          </h3>
          <p class="text-sm text-gray-400 leading-relaxed mb-4">
            Uses a <strong class="text-gray-200">general-purpose, format-agnostic
            parser</strong> that may accept multiple ISO 8601 format variants
            without being told which format to expect. This tests whether the
            implementation's primary parsing interface handles the expression
            correctly through format inference.
          </p>
          <div class="bg-gray-950/80 rounded-md p-4 text-xs font-mono text-gray-300 mb-4">
            <div class="text-gray-500 mb-1"># Example: general parser infers format</div>
            <div class="text-blue-400">Date</div>.<span class="text-emerald-400">parse</span>("1985-04-12")
            <div class="text-gray-500 mt-1"># Parser recognizes extended format without explicit format string</div>
          </div>
          <p class="text-xs text-gray-500">
            <strong class="text-gray-400">When to use:</strong> When testing
            whether a general-purpose parser correctly accepts or rejects an
            expression, without constraining the implementation to a specific
            parsing method. Useful for testing end-user-facing APIs.
          </p>
        </div>
      </section>

      <!-- 2. Generation -->
      <section>
        <h2 class="text-lg font-bold mb-4 flex items-center gap-3">
          <span class="w-2 h-2 bg-emerald-500 rounded-full"></span>
          2. Generation Tests
        </h2>
        <p class="text-sm text-gray-400 leading-relaxed mb-5">
          Generation tests verify that an implementation can produce the correct
          ISO 8601 expression string from structured date/time components. The
          test provides a set of components (year, month, day, hour, etc.) and
          expects the implementation to serialize them into the exact format
          specified.
        </p>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5 mb-4">
          <h3 class="text-xs text-gray-500 uppercase tracking-wider font-bold mb-3">Example</h3>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs">
            <div>
              <div class="text-gray-500 mb-1">Input components</div>
              <code class="text-blue-300">{ calendar: { year: 1985, month: 4, day: 12 } }</code>
            </div>
            <div class="flex items-center justify-center">
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M13 7l5 5m0 0l-5 5m5-5H6"/></svg>
            </div>
            <div>
              <div class="text-gray-500 mb-1">Expected expression</div>
              <code class="text-emerald-300">"1985-04-12"</code>
            </div>
          </div>
        </div>
        <p class="text-xs text-gray-500">
          Generation tests are particularly important for verifying that
          implementations produce <strong class="text-gray-300">exactly</strong>
          the format required by a specification, without extraneous characters
          or incorrect formatting.
        </p>
      </section>

      <!-- 3. Round-trip -->
      <section>
        <h2 class="text-lg font-bold mb-4 flex items-center gap-3">
          <span class="w-2 h-2 bg-amber-500 rounded-full"></span>
          3. Round-trip Tests
        </h2>
        <p class="text-sm text-gray-400 leading-relaxed mb-5">
          Round-trip tests exercise the full parsing-extraction-generation
          pipeline. An expression is parsed, its components are extracted, a new
          expression is generated from those components, and the result is
          compared with the original.
        </p>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5 mb-4">
          <h3 class="text-xs text-gray-500 uppercase tracking-wider font-bold mb-3">Pipeline</h3>
          <div class="flex flex-wrap items-center gap-2 text-xs font-mono">
            <span class="px-2 py-1 bg-blue-500/10 border border-blue-500/20 rounded text-blue-300">"19850412"</span>
            <span class="text-gray-600">&rarr;</span>
            <span class="px-2 py-1 bg-gray-800 rounded text-gray-400">parse</span>
            <span class="text-gray-600">&rarr;</span>
            <span class="px-2 py-1 bg-gray-800 rounded text-gray-400">extract</span>
            <span class="text-gray-600">&rarr;</span>
            <span class="px-2 py-1 bg-gray-800 rounded text-gray-400">generate</span>
            <span class="text-gray-600">&rarr;</span>
            <span class="px-2 py-1 bg-emerald-500/10 border border-emerald-500/20 rounded text-emerald-300">"19850412"</span>
          </div>
        </div>
        <p class="text-sm text-gray-400 leading-relaxed mb-4">
          A round-trip test passes when the generated expression either matches
          the original exactly, or is <strong class="text-gray-200">semantically
          equivalent</strong> (representing the same date/time value in a
          different format, e.g. basic vs extended).
        </p>
        <p class="text-xs text-gray-500">
          Round-trip testing catches subtle bugs in component extraction and
          generation that individual parsing or generation tests might miss,
          ensuring the implementation's internal representation is consistent
          across all three operations.
        </p>
      </section>

      <!-- Test type mapping -->
      <section class="border-t border-gray-800/60 pt-8">
        <h2 class="text-lg font-bold mb-4">Test Types in YAML Definitions</h2>
        <p class="text-sm text-gray-400 mb-4">
          Each conformance test in the suite specifies a
          <code class="px-1 py-0.5 bg-gray-800 rounded text-xs text-blue-300">test_type</code>
          field that maps to one of five approaches:
        </p>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg overflow-hidden">
          <table class="w-full text-xs">
            <thead>
              <tr class="border-b border-gray-800/60">
                <th class="text-left px-4 py-2.5 text-gray-400 font-bold">test_type</th>
                <th class="text-left px-4 py-2.5 text-gray-400 font-bold">Approach</th>
                <th class="text-left px-4 py-2.5 text-gray-400 font-bold">Description</th>
              </tr>
            </thead>
            <tbody class="text-gray-300">
              <tr class="border-b border-gray-800/30">
                <td class="px-4 py-2.5 font-mono text-blue-300">parsing</td>
                <td class="px-4 py-2.5"><span class="text-blue-400">Parsing</span></td>
                <td class="px-4 py-2.5 text-gray-400">Parse expression, verify validity and extracted components</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="px-4 py-2.5 font-mono text-blue-300">validity</td>
                <td class="px-4 py-2.5"><span class="text-blue-400">Parsing</span></td>
                <td class="px-4 py-2.5 text-gray-400">Parse expression, verify only validity (no component extraction)</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="px-4 py-2.5 font-mono text-emerald-300">generation</td>
                <td class="px-4 py-2.5"><span class="text-emerald-400">Generation</span></td>
                <td class="px-4 py-2.5 text-gray-400">Generate expression from components, verify output string</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="px-4 py-2.5 font-mono text-amber-300">round_trip</td>
                <td class="px-4 py-2.5"><span class="text-amber-400">Round-trip</span></td>
                <td class="px-4 py-2.5 text-gray-400">Parse &rarr; extract &rarr; generate, verify equivalence</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="px-4 py-2.5 font-mono text-purple-300">equivalence</td>
                <td class="px-4 py-2.5"><span class="text-purple-400">Equivalence</span></td>
                <td class="px-4 py-2.5 text-gray-400">Parse two expressions, verify they represent the same value</td>
              </tr>
              <tr>
                <td class="px-4 py-2.5 font-mono text-rose-300">arithmetic</td>
                <td class="px-4 py-2.5"><span class="text-rose-400">Arithmetic</span></td>
                <td class="px-4 py-2.5 text-gray-400">Perform date/time arithmetic operations</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="mt-5 bg-gray-900/50 border border-gray-800/60 rounded-lg p-4">
          <h3 class="text-xs text-gray-400 font-bold mb-2">
            <code class="text-blue-300">parse_mode</code> field (parsing/validity tests only)
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
            <div class="bg-gray-950/80 rounded p-3">
              <code class="text-blue-300">parse_mode: dedicated</code>
              <span class="text-gray-500 ml-1">(default)</span>
              <p class="text-gray-400 mt-1">Adapter uses format-specific parsing (e.g. strptime)</p>
            </div>
            <div class="bg-gray-950/80 rounded p-3">
              <code class="text-blue-300">parse_mode: undifferentiated</code>
              <p class="text-gray-400 mt-1">Adapter uses general/lenient parsing (e.g. Date.parse)</p>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>
