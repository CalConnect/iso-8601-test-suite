<script setup>
import { computed } from "vue";
import { pctBarColor } from "../composables/useStats";

const props = defineProps({
  reqs: { type: Array, required: true },
  libs: { type: Array, required: true },
  profiles: { type: Array, required: true },
});

const emit = defineEmits(["navigate"]);

function statsFor(filterFn) {
  let pass = 0, total = 0, count = 0;
  props.reqs.filter(filterFn).forEach(r => {
    count++;
    props.libs.forEach(lib => {
      const caps = r.tests?.[lib.id];
      if (!caps) return;
      Object.values(caps).forEach(cap => { total += cap.total || 0; pass += cap.pass || 0; });
    });
  });
  return { count, pass, total, pct: total ? Math.round(pass / total * 100) : 0 };
}

function pctColor(pct) {
  if (pct >= 60) return "text-emerald-400";
  if (pct >= 30) return "text-amber-400";
  return "text-red-400";
}

const standards = computed(() => [
  {
    slug: "iso-8601-1",
    label: "Part 1",
    title: "ISO 8601-1:2026",
    subtitle: "Representations",
    description: "Calendar dates, ordinal dates, week dates, time of day, date-time combinations, time intervals, durations, and recurring time intervals.",
    dot: "bg-[#e3000f]",
    accent: "from-[#e3000f]/5",
    ...statsFor(r => r.part === "1"),
  },
  {
    slug: "iso-8601-2",
    label: "Part 2",
    title: "ISO 8601-2:2026",
    subtitle: "Extensions",
    description: "Extended time intervals, grouped time scale units, set representation, qualification of uncertainty, seasons, date-time selection, arithmetic, and more.",
    dot: "bg-blue-500",
    accent: "from-blue-500/5",
    ...statsFor(r => r.part === "2"),
  },
]);

const profileCards = computed(() => props.profiles.map(p => {
  const pid = p.id.replace("profile:", "");
  const s = statsFor(r => r.profiles?.some(pr => pr.id === p.id));
  return {
    slug: pid,
    label: p.name,
    title: p.name,
    subtitle: null,
    description: p.description,
    logo: p.logo,
    dot: "bg-amber-500",
    accent: "from-amber-500/5",
    ...s,
  };
}));
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-8">
    <div class="text-center pb-8 mb-8 border-b border-gray-800/60">
      <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight mb-2">
        ISO 8601 <span class="text-[#e3000f]">Requirements</span>
      </h1>
      <p class="text-gray-500 text-sm max-w-xl mx-auto leading-relaxed">
        {{ reqs.length }} normative requirements from ISO 8601-1, ISO 8601-2, and registered profiles. Select a section to browse.
      </p>
    </div>

    <!-- ISO Standards -->
    <div class="mb-8">
      <h2 class="text-xs font-bold text-gray-500 uppercase tracking-wider mb-3 pl-1">ISO Standards</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <button
          v-for="s in standards"
          :key="s.slug"
          @click="emit('navigate', '/requirements/' + s.slug)"
          class="text-left bg-gradient-to-br border border-gray-800/60 rounded-xl p-5 transition-all hover:border-gray-600"
          :class="s.accent"
        >
          <div class="flex items-center gap-2 mb-2">
            <span class="w-2 h-2 rounded-full" :class="s.dot"></span>
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500">{{ s.label }}</span>
          </div>
          <h3 class="text-lg font-extrabold text-gray-100">{{ s.title }}</h3>
          <div v-if="s.subtitle" class="text-sm text-gray-400">{{ s.subtitle }}</div>
          <p class="text-[11px] text-gray-500 leading-relaxed mt-2 mb-4">{{ s.description }}</p>
          <div class="flex items-center gap-3">
            <span class="text-lg font-extrabold tabular-nums text-gray-100">{{ s.count }}</span>
            <span class="text-[11px] text-gray-500">requirements</span>
          </div>
          <div class="flex items-center gap-2 mt-2">
            <div class="flex-1 h-1.5 bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full rounded-full" :class="pctBarColor(s.pct)" :style="{ width: s.pct + '%' }"></div>
            </div>
            <span :class="['text-sm font-bold tabular-nums', pctColor(s.pct)]">{{ s.pct }}%</span>
          </div>
        </button>
      </div>
    </div>

    <!-- Profiles -->
    <div>
      <h2 class="text-xs font-bold text-gray-500 uppercase tracking-wider mb-3 pl-1">Profiles</h2>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        <button
          v-for="p in profileCards"
          :key="p.slug"
          @click="emit('navigate', '/requirements/' + p.slug)"
          class="text-left bg-gray-900/50 border border-gray-800/60 rounded-xl p-4 transition-all hover:border-gray-600"
        >
          <div class="flex items-center gap-2 mb-2">
            <img v-if="p.logo" :src="p.logo" :alt="p.label" class="w-5 h-5 rounded opacity-80" />
            <span class="text-[12px] font-bold text-gray-200 truncate">{{ p.label }}</span>
          </div>
          <p class="text-[10px] text-gray-500 leading-relaxed line-clamp-2 mb-3">{{ p.description }}</p>
          <div class="flex items-center gap-2">
            <span class="text-sm font-extrabold tabular-nums text-gray-200">{{ p.count }}</span>
            <span class="text-[10px] text-gray-500">requirements</span>
            <div class="flex-1"></div>
            <div class="w-12 h-1 bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full rounded-full" :class="pctBarColor(p.pct)" :style="{ width: p.pct + '%' }"></div>
            </div>
            <span :class="['text-[10px] font-bold tabular-nums', pctColor(p.pct)]">{{ p.pct }}%</span>
          </div>
        </button>
      </div>
    </div>
  </div>
</template>
