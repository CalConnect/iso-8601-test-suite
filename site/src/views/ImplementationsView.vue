<script setup>
import { computed } from "vue";
import { libStats, profileAdapterPct, stabilityLabel } from "../composables/useStats";
import { groupByFamily, libVersionLabel } from "../composables/useFormat";

const props = defineProps({
  libs: { type: Array, required: true },
  profiles: { type: Array, required: true },
  reqs: { type: Array, required: true },
  familyStats: { type: Array, default: () => [] },
});

const emit = defineEmits(["navigate"]);

const families = computed(() => groupByFamily(props.libs));

const familyStatsMap = computed(() => {
  const m = {};
  (props.familyStats || []).forEach(fs => { m[fs.family] = fs; });
  return m;
});

function fsFor(family) {
  return familyStatsMap.value[family] || null;
}

function versionDelta(libId, family) {
  const fs = fsFor(family);
  if (!fs || !fs.per_version_delta) return 0;
  return fs.per_version_delta[libId] || 0;
}

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

function detPill(det) {
  if (det === "full") return { label: "Compliant", cls: "pill pill-pass" };
  if (det === "partial") return { label: "Partial", cls: "pill pill-partial" };
  return { label: "None", cls: "pill pill-muted" };
}

function pctTone(pct) {
  if (pct >= 60) return "text-jade";
  if (pct >= 30) return "text-amber";
  return "text-rust";
}

function pctBarTone(pct) {
  if (pct >= 60) return "pass";
  if (pct >= 30) return "partial";
  return "fail";
}
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Hero -->
    <section class="relative mb-12">
      <div class="iso-watermark hidden md:block">
        <span style="top: 14%; left: 10%;">Ruby · Python · Node.js</span>
        <span style="top: 70%; right: 12%;">C · C++ · Rust · Java</span>
      </div>
      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 01</span>
          <span class="clause-label">Standard library behavior</span>
        </div>
        <h1 class="display-hero text-4xl md:text-6xl mb-4">
          <em>Implementations</em> under test.
        </h1>
        <p class="text-ink-soft text-base md:text-lg max-w-2xl leading-relaxed">
          {{ families.length }} implementation families · {{ libs.length }} versions tested against
          {{ profiles.length }} ISO 8601 profiles for conformance.
        </p>
      </div>
    </section>

    <div class="divide-y divide-rule">
      <section v-for="group in families" :key="group.family" class="py-8 first:pt-0">
        <!-- Family header -->
        <div class="flex items-center gap-4 mb-5">
          <img :src="group.logo" :alt="group.family" class="w-10 h-10 shrink-0" />
          <div class="flex-1 min-w-0">
            <div class="flex items-baseline gap-3 flex-wrap">
              <h2 class="font-display text-2xl font-medium text-ink leading-none">{{ group.family }}</h2>
              <span class="font-mono text-xs text-ink-faint uppercase tracking-wider">{{ group.language }}</span>
              <span v-if="fsFor(group.family)?.range_label"
                class="font-mono text-xs text-ink-muted tabular-nums">
                {{ fsFor(group.family).range_label }}
              </span>
            </div>
            <div class="font-mono text-xs text-ink-muted mt-1.5 tabular-nums">
              {{ group.versions.length }} version{{ group.versions.length === 1 ? '' : 's' }} under test
            </div>
          </div>
          <div v-if="fsFor(group.family)" class="shrink-0">
            <span :class="['stability-pill', `stability-${fsFor(group.family).stability}`]"
              :title="stabilityLabel(fsFor(group.family))">
              <span class="stability-dot"></span>
              <span>{{ stabilityLabel(fsFor(group.family)) }}</span>
            </span>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          <article
            v-for="lib in group.versions"
            :key="lib.id"
            :class="['surface surface-hover overflow-hidden flex flex-col', versionDelta(lib.id, group.family) > 0 ? 'version-divergent' : '']"
          >
            <button
              class="w-full text-left p-5 cursor-pointer"
              @click="emit('navigate', '/implementation/' + lib.id)"
            >
              <div class="flex items-baseline justify-between mb-4 gap-2">
                <div class="font-display text-2xl text-ink leading-none truncate">{{ libVersionLabel(lib) }}</div>
                <div class="flex items-center gap-2 shrink-0">
                  <span v-if="versionDelta(lib.id, group.family) > 0" class="delta-badge">
                    Δ {{ versionDelta(lib.id, group.family) }}
                  </span>
                  <div class="font-mono text-xs text-ink-faint">{{ lib.language }}</div>
                </div>
              </div>

              <div class="flex items-center gap-3 mb-3">
                <div class="flex-1">
                  <div class="flex items-center justify-between mb-1.5">
                    <span class="clause-label">Overall</span>
                    <span class="font-display text-lg tabular-nums" :class="pctTone(libStats(lib, reqs).pct)">{{ libStats(lib, reqs).pct }}%</span>
                  </div>
                  <div class="cap-bar">
                    <div class="cap-bar-fill"
                      :class="pctBarTone(libStats(lib, reqs).pct)"
                      :style="{ width: libStats(lib, reqs).pct + '%' }"></div>
                  </div>
                </div>
              </div>
              <div class="flex gap-3 font-mono text-[11px] mb-4 tabular-nums">
                <span class="text-jade">{{ libStats(lib, reqs).pass }} pass</span>
                <span class="text-amber">{{ libStats(lib, reqs).partial }} partial</span>
                <span class="text-rust">{{ libStats(lib, reqs).fail }} fail</span>
              </div>

              <div class="space-y-1.5">
                <div v-for="p in libProfiles(lib)" :key="p.id" class="flex items-center gap-2">
                  <img v-if="p.logo" :src="p.logo" :alt="p.name" class="w-4 h-4 shrink-0 opacity-70" />
                  <span class="font-mono text-xs text-ink-muted flex-1 truncate">{{ p.name }}</span>
                  <span :class="detPill(p.det).cls">{{ p.pct }}%</span>
                </div>
              </div>

              <div class="mt-4 font-mono text-xs text-ink-faint flex items-center gap-1">
                View full details
                <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
              </div>
            </button>

            <div class="px-5 pb-4 mt-auto">
              <a
                :href="'/results/' + lib.id + '.yaml'"
                download
                @click.stop
                class="btn-ghost text-xs"
              >
                Download YAML
                <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>
              </a>
            </div>
          </article>
        </div>
      </section>
    </div>
  </div>
</template>
