<script setup>
import { computed } from "vue";
import { libStats, profilePct, pctBarColor } from "../composables/useStats";

const props = defineProps({
  libs: { type: Array, required: true },
  reqs: { type: Array, required: true },
  profiles: { type: Array, required: true },
  categories: { type: Array, required: true },
});

const emit = defineEmits(["navigate"]);

// Unique test count (not summed across libraries)
const uniqueTestCount = computed(() => {
  const ids = new Set();
  props.reqs.forEach(r => {
    Object.values(r.tests || {}).forEach(cap => {
      Object.values(cap).forEach(c => {
        (c.details || []).forEach(d => ids.add(d.test_id));
      });
    });
  });
  return ids.size;
});

// Best library pass percentage
const bestPassPct = computed(() => {
  let best = 0;
  props.libs.forEach(lib => {
    const s = libStats(lib, props.reqs);
    if (s.pct > best) best = s.pct;
  });
  return best;
});

const baseReqCount = computed(() => props.reqs.filter(r => r.part !== "profile").length);
const profileReqCount = computed(() => props.reqs.filter(r => r.part === "profile").length);

// Cache libStats per library
const libStatsMap = computed(() => {
  const m = {};
  props.libs.forEach(lib => { m[lib.id] = libStats(lib, props.reqs); });
  return m;
});

// Dynamic hero subtitle
const heroSubtitle = computed(() => {
  const langNames = props.libs.map(l => l.language.split(" ")[0]);
  const unique = [...new Set(langNames)];
  if (unique.length === 0) return "Machine-readable test suite for ISO 8601-1:2026 and ISO 8601-2:2026 date/time formats.";
  const langs = unique.map((l, i) => i === unique.length - 1 && unique.length > 1 ? `and ${l}` : l).join(", ");
  return `Machine-readable test suite for ISO 8601-1:2026 and ISO 8601-2:2026 date/time formats. Testing standard library behavior of ${langs}.`;
});
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10">
    <!-- Hero -->
    <div class="text-center mb-12">
      <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gray-100/10 border border-gray-800/60 text-[10px] text-gray-500 font-medium tracking-wide uppercase mb-4">
        ISO/TC 154/WG 5
      </div>
      <h1 class="text-3xl md:text-4xl font-extrabold tracking-tight mb-3">
        ISO 8601 <span class="text-[#e3000f]">Conformance</span> Test Suite
      </h1>
      <p class="text-gray-400 text-sm max-w-xl mx-auto leading-relaxed">
        {{ heroSubtitle }}
      </p>
    </div>

    <!-- Stats row -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-10">
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-5 text-center">
        <div class="text-2xl font-extrabold tabular-nums text-gray-100">{{ reqs.length }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Requirements</div>
        <div class="text-[9px] text-gray-600 mt-0.5">{{ baseReqCount }} base + {{ profileReqCount }} profile-specific</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-5 text-center">
        <div class="text-2xl font-extrabold tabular-nums text-gray-100">{{ uniqueTestCount }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Test Cases</div>
        <div class="text-[9px] text-gray-600 mt-0.5">{{ libs.length }} implementations tested</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-5 text-center">
        <div class="text-2xl font-extrabold tabular-nums text-emerald-600 dark:text-emerald-400">{{ bestPassPct }}%</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Best Pass Rate</div>
        <div class="text-[9px] text-gray-600 mt-0.5">highest scoring library</div>
      </div>
      <div class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-5 text-center">
        <div class="text-2xl font-extrabold tabular-nums text-gray-100">{{ profiles.length }}</div>
        <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-1">Profiles</div>
      </div>
    </div>

    <!-- Libraries -->
    <div class="mb-10">
      <h2 class="text-lg font-bold mb-4 flex items-center gap-2">
        <span class="w-1 h-5 bg-[#e3000f] rounded-full"></span>
        Libraries Tested
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div
          v-for="lib in libs"
          :key="lib.id"
          class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-5 hover:border-gray-700 transition-colors cursor-pointer"
          @click="emit('navigate', '/implementation/' + lib.id)"
        >
          <div class="flex items-center gap-3 mb-4">
            <img :src="lib.logo" :alt="lib.name" class="w-10 h-10 rounded-lg" />
            <div>
              <div class="font-bold text-sm">{{ lib.name }}</div>
              <div class="text-[10px] text-gray-500">{{ lib.language }} {{ lib.version }}</div>
            </div>
          </div>

          <!-- Overall pass rate -->
          <div class="flex-1">
            <div class="flex items-center justify-between text-xs mb-1">
              <span class="text-gray-500">Overall</span>
              <span class="font-bold tabular-nums"
                :class="libStatsMap[lib.id].total
                  ? (libStatsMap[lib.id].pct >= 60 ? 'text-emerald-600 dark:text-emerald-400'
                    : libStatsMap[lib.id].pct >= 30 ? 'text-amber-600 dark:text-amber-400'
                    : 'text-red-500 dark:text-red-400')
                  : 'text-gray-500'">
                {{ libStatsMap[lib.id].pct }}%
              </span>
            </div>
            <div class="h-1.5 bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full rounded-full transition-all"
                :class="pctBarColor(libStatsMap[lib.id].pct)"
                :style="{ width: libStatsMap[lib.id].pct + '%' }"></div>
            </div>
          </div>
          <div class="flex gap-3 mt-3 text-[10px]">
            <span class="text-emerald-600 dark:text-emerald-400 font-medium">{{ libStatsMap[lib.id].pass }} passed</span>
            <span class="text-amber-600 dark:text-amber-400 font-medium">{{ libStatsMap[lib.id].partial }} partial</span>
            <span class="text-red-500 dark:text-red-400 font-medium">{{ libStatsMap[lib.id].fail }} failed</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Profiles overview -->
    <div class="mb-10">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-bold flex items-center gap-2">
          <span class="w-1 h-5 bg-[#e3000f] rounded-full"></span>
          Profiles
        </h2>
        <button @click="emit('navigate', '/profiles')" class="text-xs text-gray-500 hover:text-gray-300 transition-colors">
          View all →
        </button>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        <div
          v-for="p in profiles"
          :key="p.id"
          class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-5 hover:border-gray-700 transition-colors cursor-pointer"
          @click="emit('navigate', '/profile/' + p.id.replace('profile:', ''))"
        >
          <div class="flex items-center gap-2 mb-2">
            <img v-if="p.logo" :src="p.logo" :alt="p.name" class="h-5 w-auto opacity-80" />
            <div class="font-bold text-sm">{{ p.name }}</div>
          </div>
          <div v-if="p.description" class="text-[10px] text-gray-500 mb-3 line-clamp-2">{{ p.description }}</div>
          <div class="flex items-center gap-2">
            <div class="flex-1 h-1 bg-gray-800 rounded-full overflow-hidden">
              <div
                class="h-full rounded-full transition-all"
                :class="pctBarColor(profilePct(p))"
                :style="{ width: profilePct(p) + '%' }"
              ></div>
            </div>
            <span class="text-[10px] tabular-nums"
              :class="profilePct(p) >= 60 ? 'text-emerald-600 dark:text-emerald-400'
                : profilePct(p) >= 30 ? 'text-amber-600 dark:text-amber-400'
                : 'text-red-500 dark:text-red-400'">
              {{ profilePct(p) }}%
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Quick links -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
      <button
        @click="emit('navigate', '/matrix')"
        class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-5 text-left hover:border-gray-700 hover:bg-gray-900 transition-colors group"
      >
        <div class="text-sm font-bold mb-1 group-hover:text-gray-100 transition-colors">Capability Matrix</div>
        <div class="text-xs text-gray-500">Full requirements × libraries breakdown</div>
      </button>
      <button
        @click="emit('navigate', '/methodology')"
        class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-5 text-left hover:border-gray-700 hover:bg-gray-900 transition-colors group"
      >
        <div class="text-sm font-bold mb-1 group-hover:text-gray-100 transition-colors">Test Methodology</div>
        <div class="text-xs text-gray-500">Parsing, generation, and round-trip testing approaches</div>
      </button>
    </div>
  </div>
</template>
