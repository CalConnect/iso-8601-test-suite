<script setup>
import { computed } from "vue";
import { libStats, profileAdapterPct } from "../composables/useStats";
import { libShortName } from "../composables/useFormat";

const props = defineProps({
  libs: { type: Array, required: true },
  profiles: { type: Array, required: true },
  reqs: { type: Array, required: true },
});

const emit = defineEmits(["navigate"]);

function libProfiles(lib) {
  return props.profiles.map(p => {
    const ar = p.adapter_results?.find(a => a.id === lib.id);
    const total = ar?.test_total || 0;
    const pass = ar?.test_pass || 0;
    const pct = total ? Math.round(pass / total * 100) : 0;
    const statuses = [];
    p.traceability?.forEach(cc => {
      cc.requirements.forEach(r => {
        const pl = r.per_library?.find(pl => pl.library_id === lib.id);
        if (pl) statuses.push(pl.status);
      });
    });
    let det = "none";
    if (statuses.length > 0) {
      if (statuses.every(s => s === "pass")) det = "full";
      else if (statuses.some(s => s === "pass" || s === "partial")) det = "partial";
    }
    return { id: p.id, name: p.name, logo: p.logo, pct, det, pass, total };
  });
}

function detBadge(det) {
  if (det === "full") return { label: "Compliant", cls: "text-emerald-600 dark:text-emerald-400 bg-emerald-500/10" };
  if (det === "partial") return { label: "Partial", cls: "text-amber-600 dark:text-amber-400 bg-amber-500/10" };
  return { label: "None", cls: "text-gray-500 bg-gray-800/30" };
}
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-8">
    <div class="text-center pb-8 mb-8 border-b border-gray-800/60">
      <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight mb-2">
        ISO 8601 <span class="text-[#e3000f]">Implementations</span>
      </h1>
      <p class="text-gray-500 text-sm max-w-lg mx-auto leading-relaxed">
        {{ libs.length }} standard library implementations tested against {{ profiles.length }} ISO 8601 profiles for conformance.
      </p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
      <div
        v-for="lib in libs"
        :key="lib.id"
        class="bg-gray-900/50 border border-gray-800/60 rounded-xl overflow-hidden hover:border-gray-700 transition-colors group"
      >
        <button
          class="w-full text-left p-6 cursor-pointer"
          @click="emit('navigate', '/implementation/' + lib.id)"
        >
          <div class="flex items-center gap-3 mb-5">
            <img :src="lib.logo" :alt="lib.name" class="w-11 h-11 rounded-lg" />
            <div>
              <div class="font-bold text-sm group-hover:text-gray-100 transition-colors">{{ lib.name }}</div>
              <div class="text-[10px] text-gray-500">{{ lib.language }} {{ lib.version }}</div>
            </div>
          </div>

          <div class="flex items-center gap-3 mb-4">
            <div class="flex-1">
              <div class="flex items-center justify-between text-xs mb-1">
                <span class="text-gray-500">Overall</span>
                <span class="font-bold tabular-nums text-gray-100">{{ libStats(lib, reqs).pct }}%</span>
              </div>
              <div class="h-1.5 bg-gray-800 rounded-full overflow-hidden">
                <div class="h-full rounded-full bg-emerald-500" :style="{ width: libStats(lib, reqs).pct + '%' }"></div>
              </div>
            </div>
          </div>
          <div class="flex gap-3 text-[10px] mb-5">
            <span class="text-emerald-600 dark:text-emerald-400 font-medium">{{ libStats(lib, reqs).pass }} passed</span>
            <span class="text-amber-600 dark:text-amber-400 font-medium">{{ libStats(lib, reqs).partial }} partial</span>
            <span class="text-red-500 dark:text-red-400 font-medium">{{ libStats(lib, reqs).fail }} failed</span>
          </div>

          <div class="space-y-1.5">
            <div v-for="p in libProfiles(lib)" :key="p.id" class="flex items-center gap-2">
              <img v-if="p.logo" :src="p.logo" :alt="p.name" class="w-4 h-4 rounded shrink-0 opacity-70" />
              <span class="text-[11px] text-gray-500 flex-1 truncate">{{ p.name }}</span>
              <span :class="['text-[10px] font-bold px-1.5 py-0.5 rounded tabular-nums', detBadge(p.det).cls]">
                {{ p.pct }}%
              </span>
            </div>
          </div>

          <div class="mt-4 text-[10px] text-gray-600 group-hover:text-gray-400 transition-colors flex items-center gap-1">
            View full details
            <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
          </div>
        </button>

        <div class="px-6 pb-4">
          <a
            :href="'/results/' + lib.id + '.yaml'"
            download
            @click.stop
            class="inline-block px-3 py-1 bg-gray-800/50 border border-gray-700/50 rounded-md text-[10px] text-gray-500 hover:bg-[#e3000f]/10 hover:border-[#e3000f]/30 hover:text-gray-200 transition-colors no-underline"
          >
            Download YAML Results
          </a>
        </div>
      </div>
    </div>
  </div>
</template>
