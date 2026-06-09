<script setup>
const emit = defineEmits(["navigate"]);
</script>

<template>
  <div class="max-w-[900px] mx-auto px-4 md:px-8 py-8">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 text-xs text-gray-500 mb-6">
      <button @click="emit('navigate', '/')" class="hover:text-gray-300 transition-colors">Dashboard</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="text-gray-400">Developer Guide</span>
    </div>

    <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight mb-2">
      Developer <span class="text-[#e3000f]">Guide</span>
    </h1>
    <p class="text-gray-500 text-sm mb-8">
      How to test your date/time library, create adapters, and develop new profiles.
    </p>

    <!-- Quick start -->
    <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-6 mb-6">
      <h2 class="text-base font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Quick Start: Test Your Library in 5 Minutes
      </h2>
      <div class="text-sm text-gray-400 leading-relaxed space-y-3">
        <p>
          The test suite uses a <strong class="text-gray-200">pluggable adapter</strong> architecture.
          Your library doesn't need to be written in Ruby — the harness communicates with
          any process via a simple JSON protocol.
        </p>
        <ol class="list-decimal list-inside space-y-2 ml-2">
          <li>Copy the adapter template for your language</li>
          <li>Implement 4 methods: parse, extract components, generate, check equivalence</li>
          <li>Run the test suite against your adapter</li>
        </ol>
        <div class="bg-gray-950/50 rounded-lg p-4 mt-3 font-mono text-xs text-gray-300">
          <div class="text-gray-500"># Python example</div>
          <div>ruby scripts/run-tests --adapter "exec:python3 adapters/python-datetime.py"</div>
          <div class="text-gray-500 mt-2"># Node.js example</div>
          <div>ruby scripts/run-tests --adapter "exec:node adapters/node-datetime.js"</div>
          <div class="text-gray-500 mt-2"># Any executable</div>
          <div>ruby scripts/run-tests --adapter "exec:./adapters/my-rust-binary"</div>
        </div>
      </div>
    </div>

    <!-- Adapter interface -->
    <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-6 mb-6">
      <h2 class="text-base font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Adapter Interface
      </h2>
      <div class="text-sm text-gray-400 leading-relaxed space-y-4">
        <p>
          Each adapter implements a well-defined interface. The test harness calls these methods
          based on the test type:
        </p>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead>
              <tr class="border-b border-gray-800/60">
                <th class="text-left py-2 pr-4 text-gray-500 font-medium">Method</th>
                <th class="text-left py-2 text-gray-500 font-medium">Used by</th>
              </tr>
            </thead>
            <tbody class="text-gray-400">
              <tr class="border-b border-gray-800/30">
                <td class="py-2 pr-4 font-mono text-gray-300">try_parse(expr, options)</td>
                <td class="py-2">validity, parsing, round_trip, equivalence</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="py-2 pr-4 font-mono text-gray-300">extract_components(parsed)</td>
                <td class="py-2">parsing, round_trip</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="py-2 pr-4 font-mono text-gray-300">generate(components)</td>
                <td class="py-2">generation, round_trip</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="py-2 pr-4 font-mono text-gray-300">equivalent?(a, b)</td>
                <td class="py-2">equivalence</td>
              </tr>
              <tr>
                <td class="py-2 pr-4 font-mono text-gray-300">run_arithmetic(test)</td>
                <td class="py-2">arithmetic (optional)</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="mt-4">
          <h3 class="text-xs font-bold text-gray-300 mb-2">Parsing Modes</h3>
          <p class="mb-2">
            <code class="text-gray-300">try_parse</code> accepts an <code class="text-gray-300">options</code> hash with a
            <code class="text-gray-300">parse_mode</code> field:
          </p>
          <ul class="list-disc list-inside space-y-1 ml-2">
            <li><strong class="text-gray-200">dedicated</strong> (default) — format-specific parser (e.g. strptime with explicit format)</li>
            <li><strong class="text-gray-200">undifferentiated</strong> — general/lenient parser (e.g. Date.parse, fromisoformat)</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- JSON protocol -->
    <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-6 mb-6">
      <h2 class="text-base font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        JSON Protocol for Non-Ruby Implementations
      </h2>
      <div class="text-sm text-gray-400 leading-relaxed space-y-3">
        <p>
          The harness starts your adapter as a child process. For each test, it writes
          one JSON command to stdin and reads one JSON response from stdout — each on a single line.
        </p>
        <div class="bg-gray-950/50 rounded-lg p-4 font-mono text-xs">
          <div class="text-gray-500">// Request</div>
          <div class="text-gray-300">{"method":"try_parse","params":{"expression":"1985-04-12","options":{"parse_mode":"dedicated"}}}</div>
          <div class="text-gray-500 mt-2">// Response (success)</div>
          <div class="text-gray-300">{"result":{"valid":true,"parsed":"h1","api":"Date.strptime"}}</div>
          <div class="text-gray-500 mt-2">// Response (failure)</div>
          <div class="text-gray-300">{"result":{"valid":false,"error":"invalid date","api":"Date.strptime"}}</div>
        </div>
        <p class="mt-3">
          The <code class="text-gray-300">parsed</code> value is an opaque handle — your adapter caches the
          internal parsed object and returns a string key. The harness passes this key back
          to <code class="text-gray-300">extract_components</code> and <code class="text-gray-300">equivalent</code>.
        </p>
        <p>
          See <code class="text-gray-300">adapters/python-datetime.py</code> and
          <code class="text-gray-300">adapters/node-datetime.js</code> for working examples.
        </p>
      </div>
    </div>

    <!-- Test types -->
    <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-6 mb-6">
      <h2 class="text-base font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Test Types
      </h2>
      <div class="text-sm text-gray-400 leading-relaxed space-y-3">
        <div class="grid gap-3">
          <div class="flex items-start gap-3">
            <span class="text-[10px] font-bold text-gray-500 uppercase tracking-wider w-24 shrink-0 pt-0.5">Parsing</span>
            <span>expression → components. Parse a string and validate that extracted components (year, month, day, etc.) match expectations.</span>
          </div>
          <div class="flex items-start gap-3">
            <span class="text-[10px] font-bold text-gray-500 uppercase tracking-wider w-24 shrink-0 pt-0.5">Validity</span>
            <span>expression → boolean. Check if a string is syntactically valid without extracting components.</span>
          </div>
          <div class="flex items-start gap-3">
            <span class="text-[10px] font-bold text-gray-500 uppercase tracking-wider w-24 shrink-0 pt-0.5">Generation</span>
            <span>components → expression. Build an ISO 8601 string from structured components.</span>
          </div>
          <div class="flex items-start gap-3">
            <span class="text-[10px] font-bold text-gray-500 uppercase tracking-wider w-24 shrink-0 pt-0.5">Round-trip</span>
            <span>expression → parse → extract → generate → compare. Verifies that parsing and generation are inverses.</span>
          </div>
          <div class="flex items-start gap-3">
            <span class="text-[10px] font-bold text-gray-500 uppercase tracking-wider w-24 shrink-0 pt-0.5">Equivalence</span>
            <span>two expressions → boolean. Check if two expressions resolve to the same instant.</span>
          </div>
          <div class="flex items-start gap-3">
            <span class="text-[10px] font-bold text-gray-500 uppercase tracking-wider w-24 shrink-0 pt-0.5">Arithmetic</span>
            <span>expression + operation → result. Date/time arithmetic (add, subtract).</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Creating a profile -->
    <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-6 mb-6">
      <h2 class="text-base font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Creating a New Profile
      </h2>
      <div class="text-sm text-gray-400 leading-relaxed space-y-3">
        <p>
          If you're a standards body or community developing a subset of ISO 8601 for
          a specific domain, you can define a profile that selects specific requirements
          from the test suite.
        </p>
        <ol class="list-decimal list-inside space-y-2 ml-2">
          <li>Copy <code class="text-gray-300">profiles/TEMPLATE.yaml</code> to <code class="text-gray-300">profiles/{name}.yaml</code></li>
          <li>Set <code class="text-gray-300">id</code>, <code class="text-gray-300">name</code>, and <code class="text-gray-300">description</code></li>
          <li>
            Define <code class="text-gray-300">traceability</code> — list specific requirements from each
            conformance class that your profile covers
          </li>
          <li>Optionally add <code class="text-gray-300">additional_requirements</code> and <code class="text-gray-300">additional_tests</code></li>
          <li>Validate: <code class="text-gray-300">ruby scripts/validate</code></li>
          <li>Test: <code class="text-gray-300">ruby scripts/run-tests --profile {name}</code></li>
        </ol>
        <p class="mt-2">
          Available requirement IDs are defined in <code class="text-gray-300">requirements/8601-1/*.yaml</code>
          and <code class="text-gray-300">requirements/8601-2/*.yaml</code>.
        </p>
      </div>
    </div>

    <!-- Understanding results -->
    <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-6">
      <h2 class="text-base font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Understanding Results
      </h2>
      <div class="text-sm text-gray-400 leading-relaxed space-y-3">
        <div class="grid gap-2">
          <div class="flex items-start gap-3">
            <span class="text-emerald-600 dark:text-emerald-400 font-bold w-20 shrink-0 text-xs pt-0.5">PASS</span>
            <span>The implementation produced the expected result.</span>
          </div>
          <div class="flex items-start gap-3">
            <span class="text-amber-600 dark:text-amber-400 font-bold w-20 shrink-0 text-xs pt-0.5">PARTIAL</span>
            <span>Some tests for this requirement passed, but not all.</span>
          </div>
          <div class="flex items-start gap-3">
            <span class="text-red-500 dark:text-red-400 font-bold w-20 shrink-0 text-xs pt-0.5">FAIL</span>
            <span>The implementation did not produce the expected result.</span>
          </div>
          <div class="flex items-start gap-3">
            <span class="text-gray-500 font-bold w-20 shrink-0 text-xs pt-0.5">NOT-SUPPORTED</span>
            <span>The implementation does not support this feature (not counted as failure).</span>
          </div>
        </div>
        <p class="mt-3">
          A library can declare which conformance classes it targets. Tests in undeclared
          classes are marked <strong class="text-gray-200">not-supported</strong> rather than <strong class="text-gray-200">fail</strong>,
          reflecting that the library intentionally doesn't support that feature.
        </p>
      </div>
    </div>
  </div>
</template>
