<script setup>
import { computed, ref } from "vue";
import { statusColor, statusBg, statusIcon, detClass, detLabel } from "../composables/useStatus";
import { trunc } from "../composables/useFormat";
import { overallDetermination } from "../composables/useStats";

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
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-8">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 text-xs text-gray-500 mb-6">
      <button @click="emit('navigate', '/')" class="hover:text-gray-300 transition-colors">Dashboard</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/implementations')" class="hover:text-gray-300 transition-colors">Implementations</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/implementation/' + lib.id)" class="hover:text-gray-300 transition-colors">{{ lib.name }}</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="text-gray-400">{{ profile.name }}</span>
    </div>

    <!-- Header -->
    <div class="flex items-center gap-4 mb-8 pb-8 border-b border-gray-800/60">
      <img v-if="profile.logo" :src="profile.logo" :alt="profile.name" class="h-10 w-auto opacity-80" />
      <div>
        <h1 class="text-2xl font-extrabold tracking-tight">{{ profile.name }}</h1>
        <div class="flex items-center gap-3 mt-1">
          <span class="text-sm text-gray-500">{{ lib.name }}</span>
          <span :class="['text-[10px] font-bold uppercase px-2 py-0.5 rounded border', detClass(det)]">
            {{ detLabel(det) }}
          </span>
          <span class="text-xs text-gray-500">{{ reqCount() }} requirements · {{ testCount() }} tests</span>
        </div>
      </div>
      <div class="ml-auto flex items-center gap-3">
        <div class="w-24 h-2 bg-gray-800 rounded-full overflow-hidden">
          <div class="h-full rounded-full transition-all" :class="{
            'bg-emerald-500': pct >= 40,
            'bg-amber-500': pct >= 15 && pct < 40,
            'bg-red-500': pct < 15
          }" :style="{ width: pct + '%' }"></div>
        </div>
        <span class="text-sm font-bold tabular-nums">{{ pct }}%</span>
      </div>
    </div>

    <!-- Conformance class breakdown -->
    <div class="space-y-3">
      <div
        v-for="cc in traceability"
        :key="cc.id"
        class="bg-gray-900/30 border border-gray-800/40 rounded-xl overflow-hidden"
      >
        <div class="px-5 py-3 bg-gray-800/30 border-b border-gray-800/40">
          <span class="font-mono text-xs text-[#e3000f] font-semibold">{{ cc.id }}</span>
          <span class="text-gray-600 text-xs ml-2">{{ cc.requirements.length }} requirements</span>
        </div>

        <div class="divide-y divide-gray-800/30">
          <div v-for="req in cc.requirements" :key="req.requirement_id" class="px-5 py-3">
            <button class="w-full text-left flex items-start gap-3 group" @click="toggleReq(req.requirement_id)">
              <svg class="w-4 h-4 mt-0.5 shrink-0 transition-transform text-gray-600" :class="{ 'rotate-90': expandedReqs.has(req.requirement_id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap mb-0.5">
                  <span v-if="req.section" class="font-mono text-[10px] font-bold text-[#e3000f] bg-[#e3000f]/10 px-1.5 py-0.5 rounded">{{ req.section }}</span>
                  <span class="font-mono text-[11px] text-gray-500">{{ req.requirement_id.replace('req:', '') }}</span>
                  <span class="text-[10px] text-gray-600">{{ req.libraryResult?.total || 0 }} tests</span>
                </div>
                <div v-if="req.statement" class="text-[11px] text-gray-500 leading-snug">{{ trunc(req.statement, 200) }}</div>
                <div class="mt-1.5">
                  <span :class="['inline-flex items-center gap-0.5 text-[10px] font-bold px-1.5 py-0.5 rounded border', statusBg(req.libraryResult?.status)]">
                    <span :class="statusColor(req.libraryResult?.status)">{{ statusIcon(req.libraryResult?.status) }}</span>
                    <span class="text-gray-400">{{ req.libraryResult?.pass }}/{{ req.libraryResult?.total }}</span>
                  </span>
                </div>
              </div>
            </button>

            <div v-if="expandedReqs.has(req.requirement_id)" class="mt-3 ml-7 space-y-2">
              <div v-for="d in req.libraryResult?.details" :key="d.test_id" class="bg-gray-950/50 border border-gray-800/40 rounded-lg overflow-hidden">
                <button class="w-full text-left px-4 py-2.5 flex items-center gap-2" @click="toggleTest(d.test_id)">
                  <svg class="w-3 h-3 shrink-0 transition-transform text-gray-600" :class="{ 'rotate-90': expandedTests.has(d.test_id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                  <span class="font-mono text-[10px] text-gray-500">{{ d.test_id.replace('conf-test:', '') }}</span>
                  <span :class="['text-[10px] font-bold', statusColor(d.result)]">{{ statusIcon(d.result) }}</span>
                  <span class="text-[10px] text-gray-500">{{ d.result }}</span>
                  <span v-if="d.description" class="text-[10px] text-gray-400 flex-1 truncate">{{ d.description }}</span>
                </button>

                <div v-if="expandedTests.has(d.test_id)" class="px-4 pb-3 border-t border-gray-800/30">
                  <div class="mt-2 bg-gray-950 rounded-md p-3 font-mono text-[11px] space-y-2">
                    <div v-if="d.given?.expression">
                      <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Input</div>
                      <div class="text-blue-600 dark:text-blue-300">{{ d.given.expression }}</div>
                    </div>
                    <div v-if="d.given?.expression_a">
                      <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Input</div>
                      <div class="text-blue-600 dark:text-blue-300">{{ d.given.expression_a }} ≡ {{ d.given.expression_b }}</div>
                    </div>
                    <div v-if="d.given?.components">
                      <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Components</div>
                      <pre class="text-blue-600/80 dark:text-blue-300/80 text-[10px] whitespace-pre-wrap">{{ JSON.stringify(d.given.components, null, 2) }}</pre>
                    </div>
                    <div v-if="d.expect?.expression">
                      <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Expected</div>
                      <div class="text-emerald-600 dark:text-emerald-400">{{ d.expect.expression }}</div>
                    </div>
                    <div v-if="d.expect?.valid !== undefined && !d.expect?.expression">
                      <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Expected</div>
                      <pre class="text-emerald-600/80 dark:text-emerald-400/80 text-[10px] whitespace-pre-wrap">{{ JSON.stringify(d.expect, null, 2) }}</pre>
                    </div>
                    <div v-if="d.actual">
                      <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Actual</div>
                      <pre class="text-gray-400 text-[10px] whitespace-pre-wrap">{{ JSON.stringify(d.actual, null, 2) }}</pre>
                    </div>
                  </div>
                  <div v-if="d.api" class="font-mono text-[10px] text-gray-600 mt-2">API: {{ d.api }}</div>
                  <div v-if="d.notes" class="text-[11px] text-amber-600/80 dark:text-amber-500/80 mt-1">{{ d.notes }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="traceability.length === 0" class="text-center py-12 text-gray-600 text-sm">
      No traceability data available for this profile.
    </div>
  </div>
</template>
