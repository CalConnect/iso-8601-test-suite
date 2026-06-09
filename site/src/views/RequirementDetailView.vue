<script setup>
import { computed, ref } from "vue";
import { statusColor, statusBg, statusIcon } from "../composables/useStatus";
import { fmtTag, clauseUrl, formatValue } from "../composables/useFormat";
import { reqStats, pctColor, pctBarColor } from "../composables/useStats";

const props = defineProps({
  req: { type: Object, required: true },
  libs: { type: Array, required: true },
  reqs: { type: Array, required: true },
  profiles: { type: Array, required: true },
});

const emit = defineEmits(["navigate"]);

const expandedLibs = ref(new Set());
const expandedTests = ref(new Set());

function toggleLib(libId) {
  const s = new Set(expandedLibs.value);
  s.has(libId) ? s.delete(libId) : s.add(libId);
  expandedLibs.value = s;
}

function toggleTest(key) {
  const s = new Set(expandedTests.value);
  s.has(key) ? s.delete(key) : s.add(key);
  expandedTests.value = s;
}

const stats = computed(() => reqStats(props.req, props.libs));

// Test case definitions — what this requirement means in practice
const testCases = computed(() => {
  const seen = new Set();
  const cases = [];
  props.libs.forEach(lib => {
    const caps = props.req.tests?.[lib.id];
    if (!caps) return;
    Object.values(caps).forEach(cap => {
      cap.details?.forEach(d => {
        if (!seen.has(d.test_id)) {
          seen.add(d.test_id);
          cases.push({
            id: d.test_id,
            type: d.test_type,
            description: d.description,
            given: d.given,
            expect: d.expect,
          });
        }
      });
    });
  });
  return cases;
});

// Per-library test results
function testsByLib() {
  const map = {};
  props.libs.forEach(lib => {
    const caps = props.req.tests?.[lib.id];
    if (!caps) return;
    const entries = [];
    Object.entries(caps).forEach(([capKey, cap]) => {
      cap.details?.forEach(d => entries.push({ ...d, capKey }));
    });
    if (entries.length) {
      const p = entries.filter(e => e.result === "pass").length;
      const f = entries.filter(e => e.result === "fail").length;
      const ns = entries.filter(e => e.result === "not-supported").length;
      map[lib.id] = { lib, tests: entries, pass: p, fail: f, notSupported: ns, total: entries.length };
    }
  });
  return map;
}

// Related profiles
const relatedProfiles = computed(() => {
  if (props.req.profiles?.length) {
    return props.req.profiles.map(p => props.profiles.find(pp => pp.id === p.id)).filter(Boolean);
  }
  return [];
});

// Related requirements
const relatedRequirements = computed(() => {
  if (props.req.source_profile) {
    return props.reqs.filter(r => r.id !== props.req.id && r.source_profile === props.req.source_profile);
  }
  if (!props.req.clause) return [];
  const baseClause = props.req.clause.replace(/:tech:[a-z0-9-]+$/, "");
  return props.reqs.filter(r => r.id !== props.req.id && r.clause?.replace(/:tech:[a-z0-9-]+$/, "") === baseClause);
});

// Breadcrumb: link back to section page
const sectionRoute = computed(() => {
  if (props.req.source_profile) {
    return "/requirements/" + props.req.source_profile.replace("profile:", "");
  }
  if (props.req.part === "1") return "/requirements/iso-8601-1";
  if (props.req.part === "2") return "/requirements/iso-8601-2";
  return "/requirements";
});

const sectionLabel = computed(() => {
  if (props.req.source_profile) {
    const p = props.profiles.find(p => p.id === props.req.source_profile);
    return p ? p.name : props.req.source_profile;
  }
  if (props.req.part === "1") return "Part 1";
  if (props.req.part === "2") return "Part 2";
  return "Requirements";
});

function testCaseInput(tc) {
  if (!tc.given) return null;
  if (tc.given.expression) return tc.given.expression;
  if (tc.given.expression_a && tc.given.expression_b) return { a: tc.given.expression_a, b: tc.given.expression_b };
  if (tc.given.components) return tc.given.components;
  return null;
}

function testCaseExpect(tc) {
  if (!tc.expect) return null;
  if (tc.expect.expression) return { expression: tc.expect.expression };
  const parts = {};
  if (tc.expect.valid !== undefined) parts.valid = tc.expect.valid;
  if (tc.expect.equivalent !== undefined) parts.equivalent = tc.expect.equivalent;
  if (tc.expect.components) parts.components = tc.expect.components;
  return Object.keys(parts).length ? parts : null;
}

function inputDisplay(d) {
  if (!d.given) return null;
  if (d.given.expression) return d.given.expression;
  if (d.given.expression_a && d.given.expression_b) return { a: d.given.expression_a, b: d.given.expression_b };
  if (d.given.components) return d.given.components;
  return null;
}

function expectedDisplay(d) {
  if (!d.expect) return null;
  if (d.expect.expression) return { expression: d.expect.expression };
  const parts = {};
  if (d.expect.valid !== undefined) parts.valid = d.expect.valid;
  if (d.expect.equivalent !== undefined) parts.equivalent = d.expect.equivalent;
  if (d.expect.components) parts.components = d.expect.components;
  return Object.keys(parts).length ? parts : null;
}
</script>

<template>
  <div class="max-w-[1200px] mx-auto px-4 md:px-8 py-8">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 text-xs text-gray-500 mb-6">
      <button @click="emit('navigate', '/')" class="hover:text-gray-300 transition-colors">Dashboard</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/requirements')" class="hover:text-gray-300 transition-colors">Requirements</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', sectionRoute)" class="hover:text-gray-300 transition-colors">{{ sectionLabel }}</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="text-gray-400">{{ req.id.replace('req:', '') }}</span>
    </div>

    <!-- Requirement definition -->
    <div class="mb-8 pb-6 border-b border-gray-800/60">
      <div class="flex items-center gap-3 flex-wrap mb-3">
        <span v-if="req.section" class="font-mono text-[11px] font-bold text-[#e3000f] bg-[#e3000f]/10 px-2 py-1 rounded">{{ req.section }}</span>
        <h1 class="font-mono text-xl font-bold text-gray-200">{{ req.id.replace('req:', '') }}</h1>
        <span v-if="fmtTag(req.format)" class="text-[10px] px-2 py-1 rounded bg-gray-800 text-gray-500 uppercase font-bold tracking-wider">{{ fmtTag(req.format) }}</span>
        <span v-if="req.source_profile" class="text-[10px] px-2 py-1 rounded bg-[#e3000f]/10 text-[#e3000f] font-bold">Profile-Specific</span>
      </div>
      <p v-if="req.statement" class="text-gray-300 leading-relaxed max-w-3xl text-[15px]">{{ req.statement }}</p>

      <!-- Meta -->
      <div class="flex flex-wrap gap-3 mt-4">
        <span class="text-[11px] bg-gray-950 border border-gray-800/50 rounded-md px-2.5 py-1 text-gray-500">{{ req.category }}</span>
        <a v-if="req.clause" :href="clauseUrl(req.clause)" target="_blank" rel="noopener" class="text-[11px] font-mono text-gray-500 bg-gray-950 border border-gray-800/50 rounded-md px-2.5 py-1 hover:text-blue-600 dark:hover:text-blue-300 hover:border-gray-700 transition-colors no-underline">
          {{ req.clause }}
        </a>
        <span v-if="req.pattern" class="text-[11px] font-mono text-blue-600 dark:text-blue-300 bg-blue-500/5 border border-gray-800/50 rounded-md px-2.5 py-1">{{ req.pattern }}</span>
        <span v-if="req.part" class="text-[11px] bg-gray-950 border border-gray-800/50 rounded-md px-2.5 py-1 text-gray-500">Part {{ req.part }}</span>
      </div>

      <!-- Stats -->
      <div class="flex items-center gap-4 mt-5">
        <div class="flex items-center gap-2">
          <div class="w-24 h-2 bg-gray-800 rounded-full overflow-hidden">
            <div class="h-full rounded-full" :class="pctBarColor(stats.pct)" :style="{ width: stats.pct + '%' }"></div>
          </div>
          <span :class="['text-sm font-bold tabular-nums', pctColor(stats.pct)]">{{ stats.pct }}%</span>
        </div>
        <span class="text-[11px] text-gray-500">{{ stats.pass }}/{{ stats.total }} tests pass across {{ libs.length }} implementations</span>
      </div>
    </div>

    <!-- Test cases: what this requirement means -->
    <div class="mb-8">
      <h2 class="text-base font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Test Cases
        <span class="text-[11px] text-gray-600 font-normal">{{ testCases.length }} conformance tests</span>
      </h2>
      <div class="space-y-2">
        <div
          v-for="tc in testCases"
          :key="tc.id"
          class="bg-gray-900/50 border border-gray-800/60 rounded-lg px-4 py-3"
        >
          <div class="flex items-center gap-2 mb-2">
            <span class="font-mono text-[11px] text-gray-500">{{ tc.id.replace('conf-test:', '') }}</span>
            <span class="text-[9px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-500 uppercase font-bold tracking-wider">{{ tc.type }}</span>
            <span v-if="tc.description" class="text-[11px] text-gray-400 flex-1">{{ tc.description }}</span>
          </div>
          <div class="mt-1 font-mono text-[12px]">
              <!-- Input -->
              <div v-if="testCaseInput(tc)" class="flex items-baseline gap-2">
                <span class="text-[9px] uppercase tracking-wider text-gray-600 font-bold w-14 shrink-0 text-right">Input</span>
                <template v-if="typeof testCaseInput(tc) === 'string'">
                  <span class="text-blue-600 dark:text-blue-300">{{ testCaseInput(tc) }}</span>
                </template>
                <template v-else-if="testCaseInput(tc)?.a">
                  <span class="text-blue-600 dark:text-blue-300">{{ testCaseInput(tc).a }}</span>
                  <span class="text-gray-600 mx-1">≡</span>
                  <span class="text-blue-600 dark:text-blue-300">{{ testCaseInput(tc).b }}</span>
                </template>
                <template v-else>
                  <pre class="text-blue-600/80 dark:text-blue-300/80 text-[10px] whitespace-pre-wrap">{{ formatValue(testCaseInput(tc)) }}</pre>
                </template>
              </div>
              <!-- Expected -->
              <div v-if="tc.expect" class="flex items-baseline gap-2 mt-1">
                <span class="text-[9px] uppercase tracking-wider text-gray-600 font-bold w-14 shrink-0 text-right">Expected</span>
                <template v-if="tc.expect.expression">
                  <span class="text-emerald-600 dark:text-emerald-400">{{ tc.expect.expression }}</span>
                </template>
                <template v-else>
                  <span v-if="tc.expect.valid !== undefined" :class="tc.expect.valid ? 'text-emerald-600 dark:text-emerald-400' : 'text-red-400'">{{ tc.expect.valid ? 'valid' : 'invalid' }}</span>
                  <template v-if="tc.expect.components">
                    <span v-if="tc.expect.valid !== undefined" class="text-gray-600 mx-1">→</span>
                    <pre class="text-emerald-600/80 dark:text-emerald-400/80 text-[10px] inline whitespace-pre-wrap align-baseline">{{ formatValue(tc.expect.components) }}</pre>
                  </template>
                  <span v-if="tc.expect.equivalent !== undefined" class="text-emerald-600 dark:text-emerald-400"> equivalent</span>
                </template>
              </div>
            </div>
          </div>
        </div>
      </div>

    <!-- Test results per library (collapsed) -->
    <div class="mb-8">
      <h2 class="text-base font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Implementation Results
      </h2>
      <div class="space-y-2">
        <div
          v-for="({ lib, tests, pass, fail, notSupported, total }, libId) in testsByLib()"
          :key="libId"
          class="bg-gray-900/50 border border-gray-800/60 rounded-xl overflow-hidden"
        >
          <button
            class="w-full text-left px-5 py-3 flex items-center gap-3 hover:bg-gray-100/[0.02] transition-colors"
            @click="toggleLib(libId)"
          >
            <svg class="w-4 h-4 shrink-0 transition-transform text-gray-600" :class="{ 'rotate-90': expandedLibs.has(libId) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
            <img :src="lib.logo" :alt="lib.name" class="w-5 h-5 rounded" />
            <span class="text-sm font-bold text-gray-300">{{ lib.name }}</span>
            <span class="text-[11px] text-gray-600">{{ lib.language }} {{ lib.version }}</span>
            <div class="ml-auto flex items-center gap-3">
              <span class="text-[10px] text-emerald-600 dark:text-emerald-400 font-medium">{{ pass }} passed</span>
              <span v-if="fail" class="text-[10px] text-red-500 dark:text-red-400 font-medium">{{ fail }} failed</span>
              <span v-if="notSupported" class="text-[10px] text-gray-500 font-medium">{{ notSupported }} not supported</span>
              <span class="text-[10px] text-gray-600">{{ total }} total</span>
            </div>
          </button>

          <div v-if="expandedLibs.has(libId)" class="border-t border-gray-800/40 px-5 py-4">
            <div class="space-y-2">
              <div
                v-for="(d, idx) in tests"
                :key="d.test_id + d.capKey"
                class="bg-gray-950/50 border border-gray-800/40 rounded-lg overflow-hidden"
              >
                <button
                  class="w-full text-left px-4 py-2.5 flex items-center gap-2 flex-wrap hover:bg-gray-100/[0.02] transition-colors"
                  @click="toggleTest(libId + ':' + idx)"
                >
                  <svg class="w-3 h-3 shrink-0 transition-transform text-gray-600" :class="{ 'rotate-90': expandedTests.has(libId + ':' + idx) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                  <span class="text-[10px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded border" :class="statusBg(d.result)">
                    <span :class="statusColor(d.result)">{{ statusIcon(d.result) }}</span>
                  </span>
                  <span class="font-mono text-[11px] text-gray-500">{{ d.test_id.replace('conf-test:', '') }}</span>
                  <span v-if="d.result === 'not-supported'" class="text-[9px] px-1.5 py-0.5 rounded bg-gray-800/50 text-gray-600 uppercase font-bold">Not Supported</span>
                  <span class="text-[11px] text-gray-500 flex-1">{{ d.description }}</span>
                </button>

                <div v-if="expandedTests.has(libId + ':' + idx)" class="border-t border-gray-800/30 px-4 pb-3">
                  <div v-if="d.result === 'not-supported'" class="py-3 text-[11px] text-gray-500">
                    <span v-if="d.notes">{{ d.notes }}</span>
                    <span v-else>This library does not support this test type.</span>
                  </div>
                  <div v-else class="mt-2 space-y-0">
                    <div v-if="inputDisplay(d)" class="flex border-b border-gray-800/20">
                      <div class="w-24 shrink-0 text-[9px] uppercase tracking-wider text-gray-500 font-bold py-2 pr-3 text-right">Input</div>
                      <div class="py-2 font-mono text-[12px] text-blue-600 dark:text-blue-300 min-w-0 flex-1">
                        <template v-if="typeof inputDisplay(d) === 'string'">{{ inputDisplay(d) }}</template>
                        <template v-else-if="inputDisplay(d)?.a">
                          <span>{{ inputDisplay(d).a }}</span>
                          <span class="text-gray-600 mx-1">≡</span>
                          <span>{{ inputDisplay(d).b }}</span>
                        </template>
                        <template v-else>
                          <pre class="text-[11px] whitespace-pre-wrap">{{ formatValue(inputDisplay(d)) }}</pre>
                        </template>
                      </div>
                    </div>
                    <div v-if="expectedDisplay(d)" class="flex border-b border-gray-800/20">
                      <div class="w-24 shrink-0 text-[9px] uppercase tracking-wider text-gray-500 font-bold py-2 pr-3 text-right">Expected</div>
                      <div class="py-2 font-mono text-[12px] min-w-0 flex-1">
                        <template v-if="expectedDisplay(d).expression">
                          <span class="text-emerald-600 dark:text-emerald-400">{{ expectedDisplay(d).expression }}</span>
                        </template>
                        <template v-else>
                          <pre class="text-emerald-600/80 dark:text-emerald-400/80 text-[11px] whitespace-pre-wrap">{{ formatValue(expectedDisplay(d)) }}</pre>
                        </template>
                      </div>
                    </div>
                    <div v-if="d.api" class="flex border-b border-gray-800/20">
                      <div class="w-24 shrink-0 text-[9px] uppercase tracking-wider text-gray-500 font-bold py-2 pr-3 text-right">API Call</div>
                      <div class="py-2 font-mono text-[12px] text-gray-300 min-w-0 flex-1">{{ d.api }}</div>
                    </div>
                    <div v-if="d.actual" class="flex border-b border-gray-800/20">
                      <div class="w-24 shrink-0 text-[9px] uppercase tracking-wider text-gray-500 font-bold py-2 pr-3 text-right">Output</div>
                      <div class="py-2 font-mono text-[12px] min-w-0 flex-1">
                        <pre class="text-gray-400 text-[11px] whitespace-pre-wrap">{{ formatValue(d.actual) }}</pre>
                      </div>
                    </div>
                    <div class="flex">
                      <div class="w-24 shrink-0 text-[9px] uppercase tracking-wider text-gray-500 font-bold py-2 pr-3 text-right">Status</div>
                      <div class="py-2 flex items-center gap-2">
                        <span class="text-[10px] uppercase tracking-wider font-bold px-2 py-0.5 rounded border" :class="statusBg(d.result)">
                          <span :class="statusColor(d.result)">{{ statusIcon(d.result) }} {{ d.result }}</span>
                        </span>
                      </div>
                    </div>
                    <div v-if="d.notes" class="flex mt-1">
                      <div class="w-24 shrink-0"></div>
                      <div class="text-[11px] text-amber-600/80 dark:text-amber-500/80">{{ d.notes }}</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Related profiles -->
    <div v-if="relatedProfiles.length" class="mb-8">
      <h2 class="text-base font-bold mb-3 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Profiles
      </h2>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="p in relatedProfiles"
          :key="p.id"
          @click="emit('navigate', '/requirements/' + p.id.replace('profile:', ''))"
          class="flex items-center gap-2 bg-gray-900/50 border border-gray-800/60 rounded-lg px-3 py-2 hover:border-gray-700 transition-colors"
        >
          <img v-if="p.logo" :src="p.logo" :alt="p.name" class="w-4 h-4 rounded opacity-80" />
          <span class="text-[11px] font-semibold text-gray-300">{{ p.name }}</span>
        </button>
      </div>
    </div>

    <!-- Related requirements -->
    <div v-if="relatedRequirements.length" class="mb-8">
      <h2 class="text-base font-bold mb-3 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        {{ req.source_profile ? 'Sibling Requirements' : 'Related Requirements' }}
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
        <button
          v-for="r in relatedRequirements"
          :key="r.id"
          @click="emit('navigate', '/requirement/' + r.id.replace('req:', ''))"
          class="text-left bg-gray-900/50 border border-gray-800/60 rounded-lg px-4 py-3 hover:border-gray-700 transition-colors"
        >
          <div class="flex items-center gap-2 mb-1">
            <span v-if="r.section" class="font-mono text-[10px] font-bold text-[#e3000f] bg-[#e3000f]/10 px-1.5 py-0.5 rounded">{{ r.section }}</span>
            <span class="font-mono text-[11px] text-gray-500">{{ r.id.replace('req:', '') }}</span>
            <span v-if="fmtTag(r.format)" class="text-[9px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-500 uppercase font-bold tracking-wider">{{ fmtTag(r.format) }}</span>
          </div>
          <p class="text-[11px] text-gray-500 line-clamp-2 leading-snug">{{ r.statement }}</p>
        </button>
      </div>
    </div>
  </div>
</template>
