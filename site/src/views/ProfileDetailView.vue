<script setup>
import { computed, ref } from "vue";
import { statusColor, statusBg, statusIcon } from "../composables/useStatus";
import { trunc } from "../composables/useFormat";
import { overallDetermination } from "../composables/useStats";

const props = defineProps({
  profile: { type: Object, required: true },
  libs: { type: Array, required: true },
});

const emit = defineEmits(["open-detail", "navigate"]);

const expandedReqs = ref(new Set());
const expandedTests = ref(new Set());

function toggleReq(reqId) {
  const s = new Set(expandedReqs.value);
  s.has(reqId) ? s.delete(reqId) : s.add(reqId);
  expandedReqs.value = s;
}

function toggleTest(testId) {
  const s = new Set(expandedTests.value);
  s.has(testId) ? s.delete(testId) : s.add(testId);
  expandedTests.value = s;
}

function overallDetLabel(statuses) {
  const det = overallDetermination(statuses);
  if (det === "full") return { label: "Fully Compliant", class: "text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 border-emerald-500/20" };
  if (det === "partial") return { label: "Partially Compliant", class: "text-amber-600 dark:text-amber-400 bg-amber-500/10 border-amber-500/20" };
  return { label: "Not Implemented", class: "text-gray-500 bg-gray-800/30 border-gray-700/30" };
}

const totalReqs = computed(() => {
  return props.profile.traceability?.reduce((sum, cc) => sum + cc.requirements.length, 0) || 0;
});

const totalTests = computed(() => {
  return props.profile.traceability?.reduce((sum, cc) =>
    sum + cc.requirements.reduce((s, r) => s + r.tests.length, 0), 0) || 0;
});
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-8">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 text-xs text-gray-500 mb-6">
      <button @click="emit('navigate', '/')" class="hover:text-gray-300 transition-colors">Dashboard</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/profiles')" class="hover:text-gray-300 transition-colors">Profiles</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="text-gray-400">{{ profile.name }}</span>
    </div>

    <!-- Header -->
    <div class="flex items-start gap-6 mb-8 pb-8 border-b border-gray-800/60">
      <div v-if="profile.logo" class="shrink-0">
        <img :src="profile.logo" :alt="profile.name" class="h-16 w-auto" />
      </div>
      <div class="flex-1">
        <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight mb-1">{{ profile.name }}</h1>
        <div class="font-mono text-xs text-gray-500 mb-3">{{ profile.id }}</div>
        <p v-if="profile.description" class="text-sm text-gray-400 leading-relaxed max-w-2xl mb-4">{{ profile.description }}</p>
        <div v-if="profile.source?.length" class="flex flex-wrap gap-2">
          <template v-for="src in profile.source" :key="src">
            <a v-if="src.startsWith('http')" :href="src" target="_blank"
              class="inline-flex items-center gap-1 px-2.5 py-1 bg-gray-800/50 border border-gray-700/50 rounded-md text-[10px] text-gray-400 hover:text-gray-100 hover:border-gray-600 transition-colors no-underline">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
              {{ src.replace(/^https?:\/\//, '').split('/').slice(0, 2).join('/') }}
            </a>
            <span v-else class="inline-flex items-center gap-1 px-2.5 py-1 bg-gray-800/50 border border-gray-700/50 rounded-md text-[10px] text-gray-500">
              {{ src.replace(/^urn:/, '').split(':').slice(0, 3).join(':') }}
            </span>
          </template>
        </div>
      </div>
    </div>

    <!-- Summary cards -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-8">
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 text-center">
        <div class="text-xl font-extrabold tabular-nums text-gray-100">{{ profile.traceability?.length || 0 }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Traceability Classes</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 text-center">
        <div class="text-xl font-extrabold tabular-nums text-gray-100">{{ totalReqs }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Requirements</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 text-center">
        <div class="text-xl font-extrabold tabular-nums text-gray-100">{{ totalTests }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Test Cases</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 text-center">
        <div class="text-xl font-extrabold tabular-nums text-gray-100">{{ (profile.additional_requirements || []).length }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Additional Reqs</div>
      </div>
    </div>

    <!-- Library summary -->
    <div class="mb-8">
      <h2 class="text-base font-bold mb-3 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Library Compliance Summary
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div
          v-for="ar in profile.adapter_results"
          :key="ar.id"
          class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-5"
        >
          <div class="flex items-center gap-2 mb-3">
            <img :src="libs.find(l => l.id === ar.id)?.logo" :alt="ar.id" class="w-6 h-6 rounded" />
            <div class="font-bold text-sm">{{ libs.find(l => l.id === ar.id)?.name || ar.id }}</div>
          </div>
          <div class="flex items-center gap-2 mb-2">
            <div :class="['px-2 py-0.5 rounded text-[10px] font-bold uppercase border', overallDetLabel(profile.traceability?.flatMap(cc => cc.requirements.flatMap(r => r.per_library)).filter(pl => pl?.library_id === ar.id) || []).class]">
              {{ overallDetLabel(profile.traceability?.flatMap(cc => cc.requirements.flatMap(r => r.per_library)).filter(pl => pl?.library_id === ar.id) || []).label }}
            </div>
          </div>
          <div class="flex gap-4 text-[10px] mt-2">
            <span class="text-emerald-600 dark:text-emerald-400 font-medium">{{ ar.test_pass }}/{{ ar.test_total }} passed</span>
            <span class="text-amber-600 dark:text-amber-400 font-medium">{{ ar.req_partial }} partial</span>
            <span class="text-red-500 dark:text-red-400 font-medium">{{ ar.req_fail }} failed</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Additional requirements -->
    <div v-if="profile.additional_requirements?.length" class="mb-8">
      <h2 class="text-base font-bold mb-3 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Profile-Specific Requirements
      </h2>
      <div class="space-y-2">
        <div
          v-for="ar in profile.additional_requirements"
          :key="ar.id"
          class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-4 hover:border-gray-700 transition-colors cursor-pointer"
          @click="emit('navigate', '/requirement/' + ar.id.replace('req:', ''))"
        >
          <div class="font-mono text-[11px] text-[#e3000f] mb-1">{{ ar.id }}</div>
          <div class="text-xs text-gray-400 leading-relaxed">{{ ar.statement }}</div>
        </div>
      </div>
    </div>

    <!-- Traceability -->
    <div>
      <h2 class="text-base font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Requirements &amp; Test Results
      </h2>

      <div class="space-y-3">
        <div v-for="cc in profile.traceability" :key="cc.id" class="bg-gray-900/30 border border-gray-800/40 rounded-xl overflow-hidden">
          <div class="px-5 py-3 bg-gray-800/30 border-b border-gray-800/40 flex items-center justify-between">
            <div>
              <span class="font-mono text-xs text-[#e3000f] font-semibold">{{ cc.id }}</span>
              <span class="text-gray-600 text-xs ml-2">{{ cc.requirements.length }} requirements</span>
            </div>
          </div>

          <div class="divide-y divide-gray-800/30">
            <div v-for="req in cc.requirements" :key="req.requirement_id" class="px-5 py-3">
              <button class="w-full text-left flex items-start gap-3 group" @click="toggleReq(req.requirement_id)">
                <svg class="w-4 h-4 mt-0.5 shrink-0 transition-transform text-gray-600" :class="{ 'rotate-90': expandedReqs.has(req.requirement_id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 flex-wrap mb-0.5">
                    <span v-if="req.section" class="font-mono text-[10px] font-bold text-[#e3000f] bg-[#e3000f]/10 px-1.5 py-0.5 rounded">{{ req.section }}</span>
                    <button @click.stop="emit('navigate', '/requirement/' + req.requirement_id.replace('req:', ''))"
                      class="font-mono text-[11px] text-gray-500 hover:text-blue-400 transition-colors">{{ req.requirement_id.replace('req:', '') }}</button>
                    <span class="text-[10px] text-gray-600">{{ req.tests.length }} tests</span>
                  </div>
                  <div v-if="req.statement" class="text-[11px] text-gray-500 leading-snug">{{ trunc(req.statement, 200) }}</div>
                  <div class="flex gap-2 mt-1.5">
                    <span v-for="pl in req.per_library" :key="pl.library_id"
                      :class="['inline-flex items-center gap-0.5 text-[10px] font-bold px-1.5 py-0.5 rounded border', statusBg(pl.status)]">
                      <span :class="statusColor(pl.status)">{{ statusIcon(pl.status) }}</span>
                      <span class="text-gray-400">{{ pl.pass }}/{{ pl.total }}</span>
                    </span>
                  </div>
                </div>
              </button>

              <div v-if="expandedReqs.has(req.requirement_id)" class="mt-3 ml-7 space-y-2">
                <div v-for="test in req.tests" :key="test.test_id" class="bg-gray-950/50 border border-gray-800/40 rounded-lg overflow-hidden">
                  <button class="w-full text-left px-4 py-2.5 flex items-center gap-2" @click="toggleTest(test.test_id)">
                    <svg class="w-3 h-3 shrink-0 transition-transform text-gray-600" :class="{ 'rotate-90': expandedTests.has(test.test_id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                    <span class="font-mono text-[10px] text-gray-500">{{ test.test_id.replace('conf-test:', '') }}</span>
                    <span class="text-[10px] text-gray-600">·</span>
                    <span class="text-[10px] text-gray-400 flex-1 truncate">{{ test.description || test.test_type }}</span>
                    <span class="text-[9px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-500 uppercase font-semibold">{{ test.test_type }}</span>
                  </button>

                  <div v-if="expandedTests.has(test.test_id)" class="px-4 pb-3 border-t border-gray-800/30">
                    <div class="mt-2 bg-gray-950 rounded-md p-3 font-mono text-[11px] space-y-2">
                      <div v-if="test.given?.expression">
                        <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Input</div>
                        <div class="text-blue-600 dark:text-blue-300">{{ test.given.expression }}</div>
                      </div>
                      <div v-if="test.given?.expression_a">
                        <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Input</div>
                        <div class="text-blue-600 dark:text-blue-300">{{ test.given.expression_a }} ≡ {{ test.given.expression_b }}</div>
                      </div>
                      <div v-if="test.given?.components">
                        <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Components</div>
                        <pre class="text-blue-600/80 dark:text-blue-300/80 text-[10px] whitespace-pre-wrap">{{ JSON.stringify(test.given.components, null, 2) }}</pre>
                      </div>
                      <div v-if="test.expect?.expression">
                        <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Expected</div>
                        <div class="text-emerald-600 dark:text-emerald-400">{{ test.expect.expression }}</div>
                      </div>
                      <div v-if="test.expect?.valid !== undefined && !test.expect?.expression">
                        <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-0.5">Expected</div>
                        <pre class="text-emerald-600/80 dark:text-emerald-400/80 text-[10px] whitespace-pre-wrap">{{ JSON.stringify(test.expect, null, 2) }}</pre>
                      </div>
                    </div>

                    <div class="mt-2 space-y-1">
                      <div v-for="pl in req.per_library" :key="pl.library_id" class="flex items-center gap-2">
                        <img :src="libs.find(l => l.id === pl.library_id)?.logo" :alt="pl.library_id" class="w-4 h-4 rounded" />
                        <span class="text-[10px] text-gray-400 w-24 truncate">{{ libs.find(l => l.id === pl.library_id)?.name?.split(' ').slice(0, 2).join(' ') }}</span>
                        <template v-for="detail in pl.details.filter(d => d.test_id === test.test_id)" :key="detail.test_id">
                          <span :class="['text-[10px] font-bold', statusColor(detail.result)]">{{ statusIcon(detail.result) }}</span>
                          <span class="text-[10px] text-gray-500">{{ detail.result }}</span>
                          <span v-if="detail.actual" class="text-[10px] text-gray-600 font-mono truncate max-w-[200px]">{{ JSON.stringify(detail.actual) }}</span>
                          <span v-if="detail.notes" class="text-[10px] text-amber-600/70 dark:text-amber-500/70 truncate max-w-[200px]">{{ detail.notes }}</span>
                        </template>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
