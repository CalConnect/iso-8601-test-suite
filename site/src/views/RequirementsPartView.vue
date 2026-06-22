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
  "iso-8601-1": { label: "Part 1", title: "ISO 8601-1:2026 Representations", accent: true },
  "iso-8601-2": { label: "Part 2", title: "ISO 8601-2:2026 Extensions", accent: false },
};

const meta = computed(() => {
  if (SECTION_META[props.section]) return SECTION_META[props.section];
  const p = props.profiles.find(p => p.id === `profile:${props.section}` || p.id === props.section);
  return p
    ? { label: p.name, title: p.name, logo: p.logo, description: p.description }
    : { label: props.section, title: props.section };
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

function pctTone(pct) {
  if (pct >= 60) return "text-jade";
  if (pct >= 30) return "text-amber";
  return "text-rust";
}
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/requirements')" class="clause-label hover:text-accent transition-colors">Requirements</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">{{ meta.label }}</span>
    </div>

    <!-- Section header -->
    <div class="flex items-start gap-4 mb-8 pb-6 border-b border-rule">
      <img v-if="meta.logo" :src="meta.logo" :alt="meta.label" class="w-12 h-12 opacity-90 mt-1" />
      <div v-else-if="meta.accent !== undefined" class="w-3 h-14 mt-1" :class="meta.accent ? 'bg-accent' : 'bg-steel'"></div>
      <div class="flex-1">
        <div class="flex items-center gap-3 mb-2">
          <span class="clause-label" :class="meta.accent ? 'clause-label-accent' : ''">{{ meta.label }}</span>
        </div>
        <h1 class="display-hero text-3xl md:text-5xl mb-2">{{ meta.title }}</h1>
        <p v-if="meta.description" class="text-ink-soft text-base max-w-2xl leading-relaxed">{{ meta.description }}</p>
        <div class="flex items-center gap-5 mt-3 flex-wrap font-mono text-xs">
          <span class="text-ink-muted tabular-nums">{{ sectionReqs.length }} requirements</span>
          <span class="text-ink-muted tabular-nums">{{ categories.length }} categories</span>
          <div v-if="overallStats.total" class="flex items-center gap-2">
            <div class="w-20 cap-bar">
              <div class="cap-bar-fill"
                :class="pctBarColor(overallStats.pct).replace('bg-', '')"
                :style="{ width: overallStats.pct + '%' }"></div>
            </div>
            <span class="tabular-nums" :class="pctTone(overallStats.pct)">{{ overallStats.pct }}%</span>
            <span class="text-ink-faint tabular-nums">{{ overallStats.pass }}/{{ overallStats.total }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Search -->
    <div class="mb-6">
      <div class="relative max-w-md">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input v-model="q" :placeholder="'Search in ' + meta.label + '…'"
          class="surface w-full pl-9 pr-3 py-2 font-mono text-sm text-ink placeholder-ink-faint outline-none focus:border-accent/50 transition-colors" />
      </div>
      <div v-if="isSearching" class="font-mono text-xs text-ink-muted mt-2 tabular-nums">
        {{ filtered.length }} requirement{{ filtered.length !== 1 ? 's' : '' }} found
      </div>
    </div>

    <!-- Category accordion -->
    <div class="space-y-1">
      <div v-for="cat in categories" :key="cat.name" class="surface overflow-hidden">
        <button @click="toggleCat(cat.name)"
          class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-surface-2 transition-colors">
          <svg class="w-3.5 h-3.5 shrink-0 text-ink-faint transition-transform" :class="{ 'rotate-90': isOpen(cat.name) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
          <span class="font-display text-base text-ink flex-1">{{ cat.name }}</span>
          <span class="font-mono text-xs text-ink-faint tabular-nums">{{ cat.reqs.length }} reqs</span>
          <div v-if="cat.stats.total" class="w-16 cap-bar">
            <div class="cap-bar-fill"
              :class="pctBarColor(cat.stats.pct).replace('bg-', '')"
              :style="{ width: cat.stats.pct + '%' }"></div>
          </div>
          <span v-if="cat.stats.total" class="font-mono text-xs tabular-nums w-10 text-right" :class="pctTone(cat.stats.pct)">{{ cat.stats.pct }}%</span>
        </button>

        <div v-if="isOpen(cat.name)" class="border-t border-rule-soft divide-y divide-rule-soft">
          <button
            v-for="r in cat.reqs"
            :key="r.id"
            @click="emit('navigate', '/requirement/' + r.id.replace('req:', ''))"
            class="w-full text-left px-4 py-3 flex items-start gap-3 hover:bg-surface-2 transition-colors"
          >
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 flex-wrap mb-1">
                <span v-if="r.section" class="font-mono text-xs text-accent border border-accent/40 px-1.5 py-0.5 whitespace-nowrap">{{ r.section }}</span>
                <span class="font-mono text-sm text-ink">{{ r.id.replace('req:', '') }}</span>
                <span v-if="fmtTag(r.format)" class="micro-tag">{{ fmtTag(r.format) }}</span>
                <span v-if="r.source_profile" class="pill pill-info">PROFILE</span>
              </div>
              <p class="text-sm text-ink-muted leading-relaxed line-clamp-1">{{ r.statement }}</p>
            </div>
            <div class="shrink-0 flex items-center gap-2 pt-0.5">
              <span class="font-mono text-xs tabular-nums" :class="pctTone(reqStats(r).pct)">{{ reqStats(r).pct }}%</span>
              <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
            </div>
          </button>
        </div>
      </div>

      <div v-if="categories.length === 0" class="text-center py-16 clause-label">
        No requirements match your search.
      </div>
    </div>
  </div>
</template>
