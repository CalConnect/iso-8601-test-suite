<script setup>
const emit = defineEmits(["navigate"]);
</script>

<template>
  <div class="max-w-[900px] mx-auto px-4 md:px-8 py-8">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 text-xs text-gray-500 mb-6">
      <button @click="emit('navigate', '/')" class="hover:text-gray-300 transition-colors">Dashboard</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="text-gray-400">About</span>
    </div>

    <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight mb-2">
      About the ISO 8601 <span class="text-[#e3000f]">Test Suite</span>
    </h1>

    <div class="text-sm text-gray-400 leading-relaxed space-y-5 mt-6">
      <!-- What is this? -->
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
        <h2 class="text-base font-bold mb-3 flex items-center gap-2">
          <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
          What Is This?
        </h2>
        <p class="mb-3">
          This is the <strong class="text-gray-200">CalConnect TC DATETIME</strong> machine-readable
          conformance test suite for the ISO 8601 family of date/time standards, developed as joint
          work with <strong class="text-gray-200">ISO/TC 154/WG 5</strong>.
        </p>
        <p>
          It provides automated testing for any implementation that parses, generates, validates,
          or computes ISO 8601 date/time expressions — regardless of programming language. The test
          suite covers ISO 8601-1:2026 (Basic rules) and ISO 8601-2:2026 (Extensions).
        </p>
      </div>

      <!-- Data model -->
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
        <h2 class="text-base font-bold mb-3 flex items-center gap-2">
          <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
          Data Model
        </h2>
        <p class="mb-3">
          The test suite follows the
          <a href="https://www.ogc.org/standards/modspec" target="_blank" rel="noopener" class="text-blue-400 hover:text-blue-300 transition-colors">OGC ModSpec</a>
          terminology:
        </p>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <tbody>
              <tr class="border-b border-gray-800/30">
                <td class="py-1.5 pr-4 font-bold text-gray-300 w-44">Requirement</td>
                <td class="py-1.5 text-gray-400">An atomic testable criterion (a normative "shall" statement)</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="py-1.5 pr-4 font-bold text-gray-300">Requirements class</td>
                <td class="py-1.5 text-gray-400">A set of consistent requirements on a single feature area</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="py-1.5 pr-4 font-bold text-gray-300">Conformance test</td>
                <td class="py-1.5 text-gray-400">An individual test that verifies one or more requirements (pass/fail)</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="py-1.5 pr-4 font-bold text-gray-300">Conformance class</td>
                <td class="py-1.5 text-gray-400">A group of conformance tests corresponding 1:1 to a requirements class</td>
              </tr>
              <tr class="border-b border-gray-800/30">
                <td class="py-1.5 pr-4 font-bold text-gray-300">Profile</td>
                <td class="py-1.5 text-gray-400">A set of selected requirements from conformance classes, for a specific use case</td>
              </tr>
              <tr>
                <td class="py-1.5 pr-4 font-bold text-gray-300">Adapter</td>
                <td class="py-1.5 text-gray-400">A pluggable wrapper for a specific date/time library being tested</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Profiles -->
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
        <h2 class="text-base font-bold mb-3 flex items-center gap-2">
          <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
          Profiles
        </h2>
        <p class="mb-3">
          The ISO 8601 standard family includes many features and allows several different formats
          for a single feature. An <strong class="text-gray-200">ISO 8601 profile</strong> specifies
          how ISO 8601 is to be used for a particular context, selecting the necessary features and
          representations.
        </p>
        <p class="mb-2">A profile should at least contain:</p>
        <ul class="list-disc list-inside space-y-1 text-gray-400 ml-2">
          <li>Minimum features that <strong class="text-gray-200">must be supported</strong></li>
        </ul>
        <p class="mt-3 mb-2">And may optionally contain:</p>
        <ul class="list-disc list-inside space-y-1 text-gray-400 ml-2">
          <li>Features that are <strong class="text-gray-200">not relevant</strong> and need not be supported</li>
          <li><strong class="text-gray-200">Selection of specific methods</strong> where multiple exist</li>
          <li>The <strong class="text-gray-200">profile's interpretation</strong> where ambiguity exists</li>
        </ul>
        <p class="mt-3">
          ISO 8601-2 supports the creation of a registration agency for profiles. The profiles in this
          test suite include ISO-defined profiles and well-known community profiles such as
          <a href="https://www.rfc-editor.org/rfc/rfc3339" target="_blank" rel="noopener" class="text-blue-400 hover:text-blue-300 transition-colors">RFC 3339</a>
          and the
          <a href="https://www.w3.org/TR/NOTE-datetime" target="_blank" rel="noopener" class="text-blue-400 hover:text-blue-300 transition-colors">W3C Date and Time Formats</a>.
        </p>
      </div>

      <!-- For developers -->
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
        <h2 class="text-base font-bold mb-3 flex items-center gap-2">
          <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
          For Library Developers
        </h2>
        <p class="mb-3">
          If you maintain a date/time library in any language, you can test its ISO 8601 conformance
          by writing a small adapter that the test harness calls. No Ruby knowledge needed — adapters
          communicate via a simple JSON protocol.
        </p>
        <button
          @click="emit('navigate', '/developer-guide')"
          class="text-blue-400 hover:text-blue-300 transition-colors text-xs font-medium flex items-center gap-1"
        >
          Read the Developer Guide
          <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
        </button>
      </div>

      <!-- For standards bodies -->
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
        <h2 class="text-base font-bold mb-3 flex items-center gap-2">
          <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
          For Standards Bodies
        </h2>
        <p class="mb-3">
          If you're developing a profile or subset of ISO 8601 for a specific domain (e.g., healthcare,
          finance, scientific data), you can define it in a YAML file that specifies exactly which
          ISO 8601 requirements your profile covers, along with any additional requirements.
        </p>
        <button
          @click="emit('navigate', '/developer-guide')"
          class="text-blue-400 hover:text-blue-300 transition-colors text-xs font-medium flex items-center gap-1"
        >
          Profile Creation Guide
          <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
        </button>
      </div>

      <!-- Test approaches -->
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-5">
        <h2 class="text-base font-bold mb-3 flex items-center gap-2">
          <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
          Test Approaches
        </h2>
        <p class="mb-3">
          The test suite uses three complementary testing strategies to thoroughly evaluate
          date/time implementations:
        </p>
        <ul class="list-disc list-inside space-y-1 text-gray-400 ml-2">
          <li><strong class="text-gray-200">Parsing</strong> — Parse an expression and validate extracted components (dedicated or undifferentiated mode)</li>
          <li><strong class="text-gray-200">Generation</strong> — Build an expression from structured components</li>
          <li><strong class="text-gray-200">Round-trip</strong> — Parse → extract → generate → verify consistency</li>
        </ul>
        <button
          @click="emit('navigate', '/methodology')"
          class="text-blue-400 hover:text-blue-300 transition-colors text-xs font-medium flex items-center gap-1 mt-3"
        >
          Full Methodology Documentation
          <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
        </button>
      </div>
    </div>
  </div>
</template>
