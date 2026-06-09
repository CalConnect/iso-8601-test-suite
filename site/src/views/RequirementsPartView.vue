<script setup>
import { ref, computed, watch } from "vue";
import { fmtTag } from "../composables/useFormat";
import { pctBarColor } from "../composables/useStats";

const props = defineProps({
  section: { type: String, required: true },
  reqs: { type: Array, required: true },
  libs: { type: Array, required: true },
  profiles: { type: Array, required: true },
});

const emit = defineEmits(["navigate"]);

const expandedCats = ref(new Set());
const q = ref("");

watch(() => props.section, () => { expandedCats.value = new Set(); q.value = ""; });

const SECTION_META = {
  "iso-8601-1": { label: "Part 1", title: "ISO 8601-1:2026 Representations", dot: "bg-[#e3000f]", badge: "bg-[#e3000f]/10 text-[#e3000f]" },
  "iso-8601-2": { label: "Part 2", title: "ISO 8601-2:2026 Extensions", dot: "bg-blue-500", badge: "bg-blue-500/10 text-blue-400" },
};

const meta = computed(() => {
  if (SECTION_META[props.section]) return SECTION_META[props.section];
  const p = props.profiles.find(p => p.id === `profile:${props.section}` || p.id === props.section);
  return p
    ? { label: p.name, title: p.name, dot: "bg-amber-500", badge: "bg-amber-500/10 text-amber-400", logo: p.logo, description: p.description }
    : { label: props.section, title: props.section, dot: "bg-gray-500", badge: "bg-gray-500/10 text-gray-400" };
});

const sectionFilter = computed(() => {
  if (props.section === "iso-8601-1") return r => r.part === "1";
  if (props.section === "iso-8601-2") return r => r.part === "2";
  return r => r.profiles?.some(p => p.id === `profile:${props.section}` || p.id === props.section);
});

const sectionReqs = computed(() => props.reqs.filter(sectionFilter.value));

const filtered = computed(() => {
  if (!q.value) return sectionReqs.value;
  const ql = q.value.toLowerCase();
  return sectionReqs.value.filter(r =>
    r.id.toLowerCase().includes(ql) ||
    (r.section && r.section.toLowerCase().includes(ql)) ||
    (r.statement && r.statement.toLowerCase().includes(ql)) ||
    (r.pattern && r.pattern.toLowerCase().includes(ql))
  );
});

const isSearching = computed(() => q.value.length > 0);

const categories = computed(() => {
  const m = {};
  filtered.value.forEach(r => {
    const c = r.category || "Other";
    (m[c] ??= []).push(r);
  });
  return Object.entries(m)
    .map(([name, reqs]) => ({
      name,
      reqs,
      sortKey: extractClauseNum(reqs[0]?.section || ""),
      stats: aggStats(reqs),
    }))
    .sort((a, b) => a.sortKey.localeCompare(b.sortKey, undefined, { numeric: true }));
});

const overallStats = computed(() => aggStats(sectionReqs.value));

watch(q, () => {
  if (q.value) {
    const s = new Set();
    categories.value.forEach(cat => { if (cat.reqs.length) s.add(cat.name); });
    expandedCats.value = s;
  } else {
    expandedCats.value = new Set();
  }
});

function extractClauseNum(section) {
  const m = section.match(/§(\d+[\d.]*)/);
  return m ? m[1] : "zzz";
}

function aggStats(reqs) {
  let pass = 0, total = 0;
  reqs.forEach(r => {
    props.libs.forEach(lib => {
      const caps = r.tests?.[lib.id];
      if (!caps) return;
      Object.values(caps).forEach(cap => { total += cap.total || 0; pass += cap.pass || 0; });
    });
  });
  return { pass, total, pct: total ? Math.round(pass / total * 100) : 0 };
}

function reqStats(r) {
  let pass = 0, total = 0;
  props.libs.forEach(lib => {
    const caps = r.tests?.[lib.id];
    if (!caps) return;
    Object.values(caps).forEach(cap => { total += cap.total || 0; pass += cap.pass || 0; });
  });
  return { pass, total, pct: total ? Math.round(pass / total * 100) : 0 };
}

function toggleCat(name) {
  const s = new Set(expandedCats.value);
  s.has(name) ? s.delete(name) : s.add(name);
  expandedCats.value = s;
}

function isOpen(name) { return expandedCats.value.has(name); }

function pctColor(pct) {
  if (pct >= 60) return "text-emerald-400";
  if (pct >= 30) return "text-amber-400";
  return "text-red-400";
}
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-8">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 text-xs text-gray-500 mb-6">
      <button @click="emit('navigate', '/')" class="hover:text-gray-300 transition-colors">Dashboard</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/requirements')" class="hover:text-gray-300 transition-colors">Requirements</button>
      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="text-gray-400">{{ meta.label }}</span>
    </div>

    <!-- Section header -->
    <div class="flex items-start gap-4 mb-6 pb-6 border-b border-gray-800/60">
      <img v-if="meta.logo" :src="meta.logo" :alt="meta.label" class="w-10 h-10 rounded-lg opacity-80 mt-1" />
      <span v-else class="w-2 h-12 rounded-full mt-1" :class="meta.dot"></span>
      <div class="flex-1">
        <div class="flex items-center gap-2 mb-1">
          <span class="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded" :class="meta.badge">{{ meta.label }}</span>
        </div>
        <h1 class="text-2xl font-extrabold tracking-tight">{{ meta.title }}</h1>
        <p v-if="meta.description" class="text-[12px] text-gray-500 mt-1 max-w-2xl">{{ meta.description }}</p>
        <div class="flex items-center gap-4 mt-2">
          <span class="text-sm text-gray-500">{{ sectionReqs.length }} requirements</span>
          <span class="text-sm text-gray-500">{{ categories.length }} categories</span>
          <div v-if="overallStats.total" class="flex items-center gap-2">
            <div class="w-20 h-1.5 bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full rounded-full" :class="pctBarColor(overallStats.pct)" :style="{ width: overallStats.pct + '%' }"></div>
            </div>
            <span :class="['text-sm font-bold tabular-nums', pctColor(overallStats.pct)]">{{ overallStats.pct }}%</span>
            <span class="text-[11px] text-gray-600">{{ overallStats.pass }}/{{ overallStats.total }} tests</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Search -->
    <div class="mb-6">
      <div class="relative">
        <svg class="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input v-model="q" :placeholder="'Search in ' + meta.label + '…'"
          class="bg-gray-900/50 border border-gray-800/60 rounded-lg text-sm pl-8 pr-3 py-2 w-full sm:w-80 outline-none focus:border-[#e3000f]/50 transition-colors text-gray-100 placeholder-gray-600" />
      </div>
      <div v-if="isSearching" class="text-[11px] text-gray-500 mt-2">
        {{ filtered.length }} requirement{{ filtered.length !== 1 ? 's' : '' }} found
      </div>
    </div>

    <!-- Category accordion -->
    <div class="space-y-1">
      <div v-for="cat in categories" :key="cat.name" class="border border-gray-800/40 rounded-lg overflow-hidden">
        <button @click="toggleCat(cat.name)"
          class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-gray-100/[0.02] transition-colors">
          <svg class="w-3.5 h-3.5 shrink-0 text-gray-600 transition-transform" :class="{ 'rotate-90': isOpen(cat.name) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
          <span class="text-[12px] font-semibold text-gray-300 flex-1">{{ cat.name }}</span>
          <span class="text-[10px] text-gray-600 tabular-nums">{{ cat.reqs.length }} reqs</span>
          <div v-if="cat.stats.total" class="w-14 h-1 bg-gray-800 rounded-full overflow-hidden">
            <div class="h-full rounded-full" :class="pctBarColor(cat.stats.pct)" :style="{ width: cat.stats.pct + '%' }"></div>
          </div>
          <span v-if="cat.stats.total" :class="['text-[10px] font-bold tabular-nums w-8 text-right', pctColor(cat.stats.pct)]">{{ cat.stats.pct }}%</span>
        </button>

        <div v-if="isOpen(cat.name)" class="border-t border-gray-800/30">
          <button
            v-for="r in cat.reqs"
            :key="r.id"
            @click="emit('navigate', '/requirement/' + r.id.replace('req:', ''))"
            class="w-full text-left px-4 py-3 flex items-start gap-3 hover:bg-gray-100/[0.02] transition-colors border-b border-gray-800/20 last:border-b-0"
          >
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 flex-wrap mb-0.5">
                <span v-if="r.section" class="font-mono text-[9px] font-bold text-[#e3000f] bg-[#e3000f]/10 px-1.5 py-0.5 rounded whitespace-nowrap">{{ r.section }}</span>
                <span class="font-mono text-[11px] text-gray-500">{{ r.id.replace('req:', '') }}</span>
                <span v-if="fmtTag(r.format)" class="text-[8px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-500 uppercase font-bold tracking-wider">{{ fmtTag(r.format) }}</span>
                <span v-if="r.source_profile" class="text-[8px] px-1 py-0.5 rounded bg-blue-500/10 text-blue-400 font-bold">PROFILE</span>
              </div>
              <p class="text-[11px] text-gray-500 leading-relaxed line-clamp-1">{{ r.statement }}</p>
            </div>
            <div class="shrink-0 flex items-center gap-2 pt-0.5">
              <span :class="['text-[10px] font-bold tabular-nums', pctColor(reqStats(r).pct)]">{{ reqStats(r).pct }}%</span>
              <svg class="w-3 h-3 text-gray-700" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
            </div>
          </button>
        </div>
      </div>

      <div v-if="categories.length === 0" class="text-center py-16 text-gray-600 text-sm">
        No requirements match your search.
      </div>
    </div>
  </div>
</template>
