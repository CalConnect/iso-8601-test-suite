<script setup>
import { computed, ref } from "vue";
import { statusColor, statusBg, statusIcon, statusLabel, detClass, detLabel } from "../composables/useStatus";
import { trunc } from "../composables/useFormat";
import { overallDetermination, profileBarColor } from "../composables/useStats";

const props = defineProps({
  lib: { type: Object, required: true },
  profile: { type: Object, required: true },
  libs: { type: Array, required: true },
});

const emit = defineEmits(["navigate"]);

const expandedReqs = ref(new Set());
const expandedTests = ref(new Set());

function toggleReq(rid) {
  const s = new Set(expandedReqs.value);
  s.has(rid) ? s.delete(rid) : s.add(rid);
  expandedReqs.value = s;
}

function toggleTest(tid) {
  const s = new Set(expandedTests.value);
  s.has(tid) ? s.delete(tid) : s.add(tid);
  expandedTests.value = s;
}

const traceability = computed(() => {
  return (props.profile.traceability || []).map(cc => ({
    ...cc,
    requirements: (cc.requirements || []).map(r => {
      const pl = r.per_library?.find(x => x.library_id === props.lib.id);
      return { ...r, libraryResult: pl };
    }).filter(r => r.libraryResult || r.per_library)
  })).filter(cc => cc.requirements.length > 0);
});

const statuses = computed(() => {
  return traceability.value.flatMap(cc =>
    cc.requirements.map(r => r.libraryResult?.status)
  ).filter(Boolean);
});

const det = computed(() => overallDetermination(statuses.value));

const ar = computed(() => {
  return props.profile.adapter_results?.find(a => a.id === props.lib.id);
});

const pass = computed(() => ar.value?.test_pass || 0);
const total = computed(() => ar.value?.test_total || 0);
const pct = computed(() => total.value ? Math.round(pass.value / total.value * 100) : 0);

function reqCount() {
  return traceability.value.reduce((s, cc) => s + cc.requirements.length, 0);
}

function testCount() {
  return traceability.value.reduce((s, cc) =>
    s + cc.requirements.reduce((s2, r) => s2 + (r.libraryResult?.total || 0), 0), 0);
}
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/implementations')" class="clause-label hover:text-accent transition-colors">Implementations</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/implementation/' + lib.id)" class="clause-label hover:text-accent transition-colors">{{ lib.name }}</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">{{ profile.name }}</span>
    </div>

    <!-- Header -->
    <div class="flex items-start gap-6 mb-10 pb-8 border-b border-rule flex-wrap">
      <img v-if="profile.logo" :src="profile.logo" :alt="profile.name" class="h-14 w-auto" />
      <div class="flex-1 min-w-0">
        <h1 class="display-hero text-3xl md:text-4xl mb-2">{{ profile.name }}</h1>
        <div class="font-mono text-xs text-ink-faint mb-3">{{ profile.id }}</div>
        <div class="flex items-center gap-3 flex-wrap font-mono text-xs">
          <span class="text-ink-muted">{{ lib.name }}</span>
          <span :class="['pill', detClass(det)]">{{ detLabel(det) }}</span>
          <span class="text-ink-faint tabular-nums">{{ reqCount() }} requirements · {{ testCount() }} tests</span>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <div class="w-32 cap-bar">
          <div class="cap-bar-fill"
            :class="profileBarColor(pct).replace('bg-', '')"
            :style="{ width: pct + '%' }"></div>
        </div>
        <span class="font-display text-2xl tabular-nums text-ink">{{ pct }}%</span>
      </div>
    </div>

    <!-- Conformance class breakdown -->
    <div class="space-y-3">
      <div
        v-for="cc in traceability"
        :key="cc.id"
        class="surface overflow-hidden"
      >
        <div class="px-5 py-3 surface-2 border-b border-rule flex items-center justify-between">
          <div class="flex items-center gap-3">
            <span class="font-mono text-xs text-accent">{{ cc.id }}</span>
            <span class="clause-label">{{ cc.requirements.length }} requirements</span>
          </div>
        </div>

        <div class="divide-y divide-rule-soft">
          <div v-for="req in cc.requirements" :key="req.requirement_id" class="px-5 py-3">
            <button class="w-full text-left flex items-start gap-3" @click="toggleReq(req.requirement_id)">
              <svg class="w-3.5 h-3.5 mt-1 shrink-0 transition-transform text-ink-faint" :class="{ 'rotate-90': expandedReqs.has(req.requirement_id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap mb-1">
                  <span v-if="req.section" class="font-mono text-xs text-accent border border-accent/40 px-1.5 py-0.5">{{ req.section }}</span>
                  <button @click.stop="emit('navigate', '/requirement/' + req.requirement_id.replace('req:', ''))"
                    class="font-mono text-sm text-ink hover:text-accent transition-colors">{{ req.requirement_id.replace('req:', '') }}</button>
                  <span class="clause-label">{{ req.libraryResult?.total || 0 }} tests</span>
                </div>
                <div v-if="req.statement" class="text-sm text-ink-muted leading-snug">{{ trunc(req.statement, 200) }}</div>
                <div class="mt-2 flex items-center gap-2 flex-wrap">
                  <span :class="['pill', statusBg(req.libraryResult?.status)]">
                    <span>{{ statusIcon(req.libraryResult?.status) }}</span>
                    <span>{{ statusLabel(req.libraryResult?.status) }}</span>
                  </span>
                  <span v-if="req.libraryResult?.status !== 'not-supported'" class="font-mono text-xs text-ink-faint tabular-nums">{{ req.libraryResult?.pass }}/{{ req.libraryResult?.total }} tests</span>
                </div>
              </div>
            </button>

            <div v-if="expandedReqs.has(req.requirement_id)" class="mt-3 ml-7 space-y-2">
              <div v-for="d in req.libraryResult?.details" :key="d.test_id" class="surface surface-hover overflow-hidden">
                <button class="w-full text-left px-4 py-2.5 flex items-center gap-2" @click="toggleTest(d.test_id)">
                  <svg class="w-3 h-3 shrink-0 transition-transform text-ink-faint" :class="{ 'rotate-90': expandedTests.has(d.test_id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                  <span class="font-mono text-xs text-ink">{{ d.test_id.replace('conf-test:', '') }}</span>
                  <span class="text-sm" :class="statusColor(d.result)">{{ statusIcon(d.result) }}</span>
                  <span class="font-mono text-xs text-ink-muted">{{ statusLabel(d.result) }}</span>
                  <span v-if="d.description" class="text-xs text-ink-muted flex-1 truncate">{{ d.description }}</span>
                </button>

                <div v-if="expandedTests.has(d.test_id)" class="px-4 pb-3 border-t border-rule-soft">
                  <div class="mt-2 surface-2 p-3 font-mono text-sm space-y-2">
                    <div v-if="d.given?.expression">
                      <div class="clause-label mb-0.5">Input</div>
                      <div class="text-steel">{{ d.given.expression }}</div>
                    </div>
                    <div v-if="d.given?.expression_a">
                      <div class="clause-label mb-0.5">Input</div>
                      <div class="text-steel">{{ d.given.expression_a }} ≡ {{ d.given.expression_b }}</div>
                    </div>
                    <div v-if="d.given?.components">
                      <div class="clause-label mb-0.5">Components</div>
                      <pre class="text-steel/80 text-xs whitespace-pre-wrap">{{ JSON.stringify(d.given.components, null, 2) }}</pre>
                    </div>
                    <div v-if="d.expect?.expression">
                      <div class="clause-label mb-0.5">Expected</div>
                      <div class="text-jade">{{ d.expect.expression }}</div>
                    </div>
                    <div v-if="d.expect?.valid !== undefined && !d.expect?.expression">
                      <div class="clause-label mb-0.5">Expected</div>
                      <pre class="text-jade/80 text-xs whitespace-pre-wrap">{{ JSON.stringify(d.expect, null, 2) }}</pre>
                    </div>
                    <div v-if="d.actual">
                      <div class="clause-label mb-0.5">Actual</div>
                      <pre class="text-ink-muted text-xs whitespace-pre-wrap">{{ JSON.stringify(d.actual, null, 2) }}</pre>
                    </div>
                  </div>
                  <div v-if="d.api" class="font-mono text-xs text-ink-faint mt-2">API: {{ d.api }}</div>
                  <div v-if="d.notes" class="text-sm text-amber mt-1">{{ d.notes }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="traceability.length === 0" class="text-center py-16 clause-label">
      No traceability data available for this profile.
    </div>
  </div>
</template>
