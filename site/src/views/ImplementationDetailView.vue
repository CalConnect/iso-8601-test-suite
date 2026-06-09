<script setup>
import { computed } from "vue";
import { detClass, detLabel } from "../composables/useStatus";
import { libStats, overallDetermination } from "../composables/useStats";

const props = defineProps({
  lib: { type: Object, required: true },
  profiles: { type: Array, required: true },
  reqs: { type: Array, required: true },
  libs: { type: Array, required: true },
});

const emit = defineEmits(["navigate"]);

const stats = computed(() => libStats(props.lib, props.reqs));

const profileData = computed(() => {
  return props.profiles.map(p => {
    const ar = p.adapter_results?.find(a => a.id === props.lib.id);
    const traceability = p.traceability?.map(cc => ({
      ...cc,
      requirements: (cc.requirements || []).filter(r => {
        const pl = r.per_library?.find(x => x.library_id === props.lib.id);
        return pl;
      })
    })).filter(cc => cc.requirements.length > 0);

    const statuses = traceability?.flatMap(cc =>
      cc.requirements.map(r => {
        const pl = r.per_library?.find(x => x.library_id === props.lib.id);
        return pl?.status;
      })
    ).filter(Boolean) || [];

    const det = overallDetermination(statuses);

    const total = ar?.test_total || 0;
    const pass = ar?.test_pass || 0;
    return { ...p, adapterResult: ar, det, pass, total, pct: total ? Math.round(pass / total * 100) : 0 };
  });
});

function openReport(p) {
  const profileId = p.id.startsWith("profile:") ? p.id.replace("profile:", "") : p.id;
  emit("navigate", `/implementation/${props.lib.id}/report/${profileId}`);
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
      <span class="text-gray-400">{{ lib.name }}</span>
    </div>

    <!-- Header -->
    <div class="flex items-start gap-5 mb-8 pb-8 border-b border-gray-800/60">
      <img :src="lib.logo" :alt="lib.name" class="w-14 h-14 rounded-xl" />
      <div class="flex-1">
        <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight">{{ lib.name }}</h1>
        <div class="text-sm text-gray-500 mt-0.5">{{ lib.language }} {{ lib.version }}</div>
        <a
          :href="'/results/' + lib.id + '.yaml'"
          download
          class="inline-block mt-2 px-3 py-1 bg-gray-800/50 border border-gray-700/50 rounded-md text-[10px] text-gray-500 hover:bg-[#e3000f]/10 hover:border-[#e3000f]/30 hover:text-gray-200 transition-colors no-underline"
        >Download YAML Results</a>
      </div>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 md:grid-cols-5 gap-3 mb-8">
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 text-center">
        <div class="text-xl font-extrabold tabular-nums text-gray-100">{{ stats.total }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Capabilities</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 text-center">
        <div class="text-xl font-extrabold tabular-nums text-emerald-600 dark:text-emerald-400">{{ stats.pass }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Passed</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 text-center">
        <div class="text-xl font-extrabold tabular-nums text-amber-600 dark:text-amber-400">{{ stats.partial }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Partial</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 text-center">
        <div class="text-xl font-extrabold tabular-nums text-red-500 dark:text-red-400">{{ stats.fail }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Failed</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 text-center">
        <div class="text-xl font-extrabold tabular-nums text-gray-100">{{ stats.pct }}%</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Pass Rate</div>
      </div>
    </div>

    <!-- Profile compliance cards -->
    <div class="mb-8">
      <h2 class="text-base font-bold mb-3 flex items-center gap-2">
        <span class="w-1 h-4 bg-[#e3000f] rounded-full"></span>
        Profile Compliance
      </h2>
      <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        <button
          v-for="p in profileData"
          :key="p.id"
          @click="openReport(p)"
          class="text-left bg-gray-900/50 border border-gray-800/60 hover:border-gray-700 rounded-xl p-4 transition-all cursor-pointer"
        >
          <div class="flex items-center gap-2 mb-2">
            <img v-if="p.logo" :src="p.logo" :alt="p.name" class="w-5 h-5 rounded opacity-80" />
            <div class="font-bold text-[11px] truncate flex-1">{{ p.name }}</div>
          </div>
          <div :class="['text-[10px] font-bold uppercase px-1.5 py-0.5 rounded border inline-block mb-2', detClass(p.det)]">
            {{ detLabel(p.det) }}
          </div>
          <div class="flex items-center gap-2">
            <div class="flex-1 h-1 bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full rounded-full transition-all" :class="{
                'bg-emerald-500': p.pct >= 40,
                'bg-amber-500': p.pct >= 15 && p.pct < 40,
                'bg-red-500': p.pct < 15
              }" :style="{ width: p.pct + '%' }"></div>
            </div>
            <span class="text-[10px] tabular-nums text-gray-500">{{ p.pct }}%</span>
          </div>
          <div class="text-[9px] text-gray-600 mt-1.5">{{ p.pass }}/{{ p.total }} tests</div>
        </button>
      </div>
    </div>

    <div class="text-center py-6 text-gray-600 text-sm">
      Click a profile above to view the detailed test report.
    </div>
  </div>
</template>
