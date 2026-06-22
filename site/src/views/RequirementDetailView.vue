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

const relatedProfiles = computed(() => {
  if (props.req.profiles?.length) {
    return props.req.profiles.map(p => props.profiles.find(pp => pp.id === p.id)).filter(Boolean);
  }
  return [];
});

const relatedRequirements = computed(() => {
  if (props.req.source_profile) {
    return props.reqs.filter(r => r.id !== props.req.id && r.source_profile === props.req.source_profile);
  }
  if (!props.req.clause) return [];
  const baseClause = props.req.clause.replace(/:tech:[a-z0-9-]+$/, "");
  return props.reqs.filter(r => r.id !== props.req.id && r.clause?.replace(/:tech:[a-z0-9-]+$/, "") === baseClause);
});

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
  <div class="max-w-[1200px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/requirements')" class="clause-label hover:text-accent transition-colors">Requirements</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', sectionRoute)" class="clause-label hover:text-accent transition-colors">{{ sectionLabel }}</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">{{ req.id.replace('req:', '') }}</span>
    </div>

    <!-- Requirement definition -->
    <div class="mb-12 pb-8 border-b border-rule">
      <div class="flex items-center gap-3 flex-wrap mb-4">
        <span v-if="req.section" class="font-mono text-xs font-medium text-accent border border-accent/40 px-2 py-1">{{ req.section }}</span>
        <h1 class="font-mono text-xl md:text-2xl text-ink">{{ req.id.replace('req:', '') }}</h1>
        <span v-if="fmtTag(req.format)" class="micro-tag border border-rule px-2 py-1">{{ fmtTag(req.format) }}</span>
        <span v-if="req.source_profile" class="pill pill-info">Profile-Specific</span>
      </div>
      <p v-if="req.statement" class="font-display text-2xl md:text-3xl text-ink-soft leading-snug max-w-4xl mb-6">{{ req.statement }}</p>

      <!-- Meta -->
      <div class="flex flex-wrap gap-2 mb-6">
        <span class="font-mono text-xs text-ink-muted border border-rule px-2.5 py-1">{{ req.category }}</span>
        <a v-if="req.clause" :href="clauseUrl(req.clause)" target="_blank" rel="noopener"
          class="font-mono text-xs text-ink-muted border border-rule px-2.5 py-1 hover:text-accent hover:border-accent/50 transition-colors no-underline">
          {{ req.clause }}
        </a>
        <span v-if="req.pattern" class="font-mono text-xs text-steel border border-steel/30 bg-surface-2 px-2.5 py-1">{{ req.pattern }}</span>
        <span v-if="req.part" class="font-mono text-xs text-ink-muted border border-rule px-2.5 py-1">Part {{ req.part }}</span>
      </div>

      <!-- Stats -->
      <div class="flex items-center gap-4 flex-wrap">
        <div class="flex items-center gap-3">
          <div class="w-32 cap-bar">
            <div class="cap-bar-fill"
              :class="pctBarColor(stats.pct).replace('bg-', '')"
              :style="{ width: stats.pct + '%' }"></div>
          </div>
          <span class="font-display text-2xl tabular-nums" :class="pctColor(stats.pct)">{{ stats.pct }}%</span>
        </div>
        <span class="font-mono text-xs text-ink-muted tabular-nums">
          {{ stats.pass }}/{{ stats.total }} tests pass across {{ libs.length }} implementations
        </span>
      </div>
    </div>

    <!-- Test cases -->
    <div class="mb-12">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">Test cases</h2>
        <span class="section-meta">{{ testCases.length }} conformance tests</span>
      </div>
      <div class="space-y-2">
        <div
          v-for="tc in testCases"
          :key="tc.id"
          class="surface p-4"
        >
          <div class="flex items-center gap-2 mb-3 flex-wrap">
            <span class="font-mono text-sm text-ink">{{ tc.id.replace('conf-test:', '') }}</span>
            <span class="micro-tag border border-rule px-2 py-0.5">{{ tc.type }}</span>
            <span v-if="tc.description" class="text-sm text-ink-muted flex-1">{{ tc.description }}</span>
          </div>
          <div class="font-mono text-sm space-y-1.5">
            <div v-if="testCaseInput(tc)" class="flex items-baseline gap-3">
              <span class="clause-label w-16 shrink-0 text-right">Input</span>
              <template v-if="typeof testCaseInput(tc) === 'string'">
                <span class="text-steel">{{ testCaseInput(tc) }}</span>
              </template>
              <template v-else-if="testCaseInput(tc)?.a">
                <span class="text-steel">{{ testCaseInput(tc).a }}</span>
                <span class="text-ink-faint mx-1">≡</span>
                <span class="text-steel">{{ testCaseInput(tc).b }}</span>
              </template>
              <template v-else>
                <pre class="text-steel/80 text-xs whitespace-pre-wrap">{{ formatValue(testCaseInput(tc)) }}</pre>
              </template>
            </div>
            <div v-if="tc.expect" class="flex items-baseline gap-3">
              <span class="clause-label w-16 shrink-0 text-right">Expected</span>
              <template v-if="tc.expect.expression">
                <span class="text-jade">{{ tc.expect.expression }}</span>
              </template>
              <template v-else>
                <span v-if="tc.expect.valid !== undefined" :class="tc.expect.valid ? 'text-jade' : 'text-rust'">{{ tc.expect.valid ? 'valid' : 'invalid' }}</span>
                <template v-if="tc.expect.components">
                  <span v-if="tc.expect.valid !== undefined" class="text-ink-faint mx-1">→</span>
                  <pre class="text-jade/80 text-xs inline whitespace-pre-wrap align-baseline">{{ formatValue(tc.expect.components) }}</pre>
                </template>
                <span v-if="tc.expect.equivalent !== undefined" class="text-jade"> equivalent</span>
              </template>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Test results per library -->
    <div class="mb-12">
      <div class="section-header">
        <span class="section-number">§ 02</span>
        <h2 class="section-title">Implementation results</h2>
      </div>
      <div class="space-y-2">
        <div
          v-for="({ lib, tests, pass, fail, notSupported, total }, libId) in testsByLib()"
          :key="libId"
          class="surface overflow-hidden"
        >
          <button
            class="w-full text-left px-5 py-3.5 flex items-center gap-3 hover:bg-surface-2 transition-colors"
            @click="toggleLib(libId)"
          >
            <svg class="w-3.5 h-3.5 shrink-0 transition-transform text-ink-faint" :class="{ 'rotate-90': expandedLibs.has(libId) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
            <img :src="lib.logo" :alt="lib.name" class="w-5 h-5" />
            <span class="font-display text-base text-ink">{{ lib.name }}</span>
            <span class="font-mono text-xs text-ink-faint">{{ lib.language }} {{ lib.version }}</span>
            <div class="ml-auto flex items-center gap-3 font-mono text-xs tabular-nums">
              <span class="text-jade">{{ pass }} pass</span>
              <span v-if="fail" class="text-rust">{{ fail }} fail</span>
              <span v-if="notSupported" class="text-ink-faint">{{ notSupported }} n/s</span>
              <span class="text-ink-faint">{{ total }}</span>
            </div>
          </button>

          <div v-if="expandedLibs.has(libId)" class="border-t border-rule-soft px-5 py-4">
            <div class="space-y-2">
              <div
                v-for="(d, idx) in tests"
                :key="d.test_id + d.capKey"
                class="surface surface-hover overflow-hidden"
              >
                <button
                  class="w-full text-left px-4 py-2.5 flex items-center gap-2 flex-wrap"
                  @click="toggleTest(libId + ':' + idx)"
                >
                  <svg class="w-3 h-3 shrink-0 transition-transform text-ink-faint" :class="{ 'rotate-90': expandedTests.has(libId + ':' + idx) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                  <span :class="['pill', statusBg(d.result)]">
                    <span>{{ statusIcon(d.result) }}</span>
                  </span>
                  <span class="font-mono text-xs text-ink">{{ d.test_id.replace('conf-test:', '') }}</span>
                  <span v-if="d.result === 'not-supported'" class="micro-tag">n/s</span>
                  <span class="text-sm text-ink-muted flex-1">{{ d.description }}</span>
                </button>

                <div v-if="expandedTests.has(libId + ':' + idx)" class="border-t border-rule-soft px-4 pb-3">
                  <div v-if="d.result === 'not-supported'" class="py-3 text-sm text-ink-muted">
                    <span v-if="d.notes">{{ d.notes }}</span>
                    <span v-else>This library does not support this test type.</span>
                  </div>
                  <div v-else class="mt-2 divide-y divide-rule-soft">
                    <div v-if="inputDisplay(d)" class="flex">
                      <div class="w-24 shrink-0 clause-label py-2 pr-3 text-right">Input</div>
                      <div class="py-2 font-mono text-sm text-steel min-w-0 flex-1">
                        <template v-if="typeof inputDisplay(d) === 'string'">{{ inputDisplay(d) }}</template>
                        <template v-else-if="inputDisplay(d)?.a">
                          <span>{{ inputDisplay(d).a }}</span>
                          <span class="text-ink-faint mx-1">≡</span>
                          <span>{{ inputDisplay(d).b }}</span>
                        </template>
                        <template v-else>
                          <pre class="whitespace-pre-wrap">{{ formatValue(inputDisplay(d)) }}</pre>
                        </template>
                      </div>
                    </div>
                    <div v-if="expectedDisplay(d)" class="flex">
                      <div class="w-24 shrink-0 clause-label py-2 pr-3 text-right">Expected</div>
                      <div class="py-2 font-mono text-sm min-w-0 flex-1">
                        <template v-if="expectedDisplay(d).expression">
                          <span class="text-jade">{{ expectedDisplay(d).expression }}</span>
                        </template>
                        <template v-else>
                          <pre class="text-jade/80 whitespace-pre-wrap">{{ formatValue(expectedDisplay(d)) }}</pre>
                        </template>
                      </div>
                    </div>
                    <div v-if="d.api" class="flex">
                      <div class="w-24 shrink-0 clause-label py-2 pr-3 text-right">API Call</div>
                      <div class="py-2 font-mono text-sm text-ink-soft min-w-0 flex-1">{{ d.api }}</div>
                    </div>
                    <div v-if="d.actual" class="flex">
                      <div class="w-24 shrink-0 clause-label py-2 pr-3 text-right">Output</div>
                      <div class="py-2 font-mono text-sm min-w-0 flex-1">
                        <pre class="text-ink-muted whitespace-pre-wrap">{{ formatValue(d.actual) }}</pre>
                      </div>
                    </div>
                    <div class="flex">
                      <div class="w-24 shrink-0 clause-label py-2 pr-3 text-right">Status</div>
                      <div class="py-2 flex items-center gap-2">
                        <span :class="['pill', statusBg(d.result)]">
                          {{ statusIcon(d.result) }} {{ d.result }}
                        </span>
                      </div>
                    </div>
                    <div v-if="d.notes" class="flex">
                      <div class="w-24 shrink-0"></div>
                      <div class="text-sm text-amber py-2">{{ d.notes }}</div>
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
      <div class="section-header">
        <span class="section-number">§ 03</span>
        <h2 class="section-title">Profiles</h2>
      </div>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="p in relatedProfiles"
          :key="p.id"
          @click="emit('navigate', '/requirements/' + p.id.replace('profile:', ''))"
          class="surface surface-hover flex items-center gap-2 px-3 py-2 cursor-pointer"
        >
          <img v-if="p.logo" :src="p.logo" :alt="p.name" class="w-4 h-4 opacity-90" />
          <span class="font-display text-sm text-ink">{{ p.name }}</span>
        </button>
      </div>
    </div>

    <!-- Related requirements -->
    <div v-if="relatedRequirements.length" class="mb-8">
      <div class="section-header">
        <span class="section-number">§ 04</span>
        <h2 class="section-title">{{ req.source_profile ? 'Sibling requirements' : 'Related requirements' }}</h2>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
        <button
          v-for="r in relatedRequirements"
          :key="r.id"
          @click="emit('navigate', '/requirement/' + r.id.replace('req:', ''))"
          class="surface surface-hover text-left px-4 py-3 cursor-pointer"
        >
          <div class="flex items-center gap-2 mb-1 flex-wrap">
            <span v-if="r.section" class="font-mono text-xs text-accent border border-accent/40 px-1.5 py-0.5">{{ r.section }}</span>
            <span class="font-mono text-sm text-ink">{{ r.id.replace('req:', '') }}</span>
            <span v-if="fmtTag(r.format)" class="micro-tag">{{ fmtTag(r.format) }}</span>
          </div>
          <p class="text-sm text-ink-muted line-clamp-2 leading-snug">{{ r.statement }}</p>
        </button>
      </div>
    </div>
  </div>
</template>
