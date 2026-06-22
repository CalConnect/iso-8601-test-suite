<script setup>
import { computed } from "vue";
import { libStats, profilePct, pctBarColor, meanPassPct, stabilityLabel } from "../composables/useStats";
import { groupByFamily, libVersionLabel } from "../composables/useFormat";
import { useMOTD } from "../composables/useMOTD";
import { useCountUp } from "../composables/useCountUp";

const props = defineProps({
  libs: { type: Array, required: true },
  reqs: { type: Array, required: true },
  profiles: { type: Array, required: true },
  categories: { type: Array, required: true },
  familyStats: { type: Array, default: () => [] },
});

const emit = defineEmits(["navigate"]);

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

function versionsToShow(group) {
  const fs = fsFor(group.family);
  if (fs && fs.stability !== "stable" && fs.stability !== "single") {
    return group.versions;
  }
  return group.versions.slice(0, 2);
}

function hiddenCount(group) {
  return Math.max(0, group.versions.length - versionsToShow(group).length);
}

const stabilitySummary = computed(() => {
  const all = props.familyStats || [];
  if (all.length === 0) return null;
  const stable = all.filter(fs => fs.stability === "stable" || fs.stability === "single").length;
  const divergentTests = all.reduce((sum, fs) => sum + (fs.delta_count || 0), 0);
  const divergentFamilies = all.filter(fs => fs.delta_count > 0).length;
  return { total: all.length, stable, divergentTests, divergentFamilies };
});

const uniqueTestCount = computed(() => {
  let count = 0;
  props.reqs.forEach(r => {
    const capMax = {};
    Object.values(r.tests || {}).forEach(caps => {
      Object.entries(caps || {}).forEach(([capKey, cap]) => {
        const t = cap.total || 0;
        if (!(capKey in capMax) || t > capMax[capKey]) capMax[capKey] = t;
      });
    });
    count += Object.values(capMax).reduce((a, b) => a + b, 0);
  });
  return count;
});

const bestPassPct = computed(() => {
  let best = 0;
  props.libs.forEach(lib => {
    const s = libStats(lib, props.reqs);
    if (s.pct > best) best = s.pct;
  });
  return best;
});

const meanPct = computed(() => meanPassPct(props.libs, props.reqs));
const meanPctDisplay = useCountUp(meanPct, { duration: 1400 });

const baseReqCount = computed(() => props.reqs.filter(r => r.part !== "profile").length);
const profileReqCount = computed(() => props.reqs.filter(r => r.part === "profile").length);

const libStatsMap = computed(() => {
  const m = {};
  props.libs.forEach(lib => { m[lib.id] = libStats(lib, props.reqs); });
  return m;
});

const families = computed(() => groupByFamily(props.libs));
const familyCount = computed(() => families.value.length);

const heroSubtitle = computed(() => {
  const langNames = props.libs.map(l => l.language.split(" ")[0]);
  const unique = [...new Set(langNames)];
  if (unique.length === 0) return "Machine-readable test suite for ISO 8601-1:2026 and ISO 8601-2:2026 date/time formats.";
  const langs = unique.map((l, i) => i === unique.length - 1 && unique.length > 1 ? `and ${l}` : l).join(", ");
  return `Machine-readable test suite for ISO 8601-1:2026 and ISO 8601-2:2026 date/time formats. Testing standard library behavior of ${langs}.`;
});

const { current: motdText } = useMOTD({
  reqs: computed(() => props.reqs.length),
  libs: computed(() => props.libs.length),
  profiles: computed(() => props.profiles.length),
  tests: computed(() => uniqueTestCount.value),
  bestPct: computed(() => bestPassPct.value),
  meanPct: computed(() => meanPct.value),
  familyCount: computed(() => familyCount.value),
});

const pctTone = (pct) => {
  if (pct >= 60) return "text-jade";
  if (pct >= 30) return "text-amber";
  return "text-rust";
};

const capBarTone = (pct) => {
  if (pct >= 60) return "pass";
  if (pct >= 30) return "partial";
  return "fail";
};
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- ── § 00 — Hero ───────────────────────────────────────────────── -->
    <section class="relative mb-16 md:mb-20">
      <!-- Decorative watermark -->
      <div class="iso-watermark hidden md:block">
        <span style="top: 8%; left: 4%;">2026-04-12T23:20:30Z</span>
        <span style="top: 22%; right: 6%;">19850412</span>
        <span style="top: 38%; left: 12%;">+02:00</span>
        <span style="top: 60%; right: 18%;">P3Y6M4DT12H30M5S</span>
        <span style="top: 78%; left: 28%;">--04-12</span>
        <span style="top: 12%; right: 32%;">T23:20:30</span>
        <span style="top: 88%; left: 58%;">2026-W15-3</span>
      </div>

      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 00</span>
          <span class="clause-label">ISO/TC 154/WG 5 · CalConnect TC DATETIME</span>
        </div>

        <h1 class="display-hero text-5xl md:text-7xl mb-5 max-w-5xl">
          The ISO 8601 <em>conformance</em><br/>test suite, in machine-readable form.
        </h1>

        <!-- MOTD: rotating intelligent phrase -->
        <div class="flex items-center gap-3 mb-10 min-h-[1.75rem]">
          <span class="inline-block w-2 h-2 bg-accent rounded-full pulse-dot shrink-0"></span>
          <span
            :key="motdText"
            class="motd-enter font-mono text-base md:text-lg uppercase tracking-wider text-accent"
          >{{ motdText }}</span>
        </div>

        <div class="grid md:grid-cols-[1fr_auto] gap-6 items-end">
          <p class="text-ink-soft text-base md:text-lg max-w-xl leading-relaxed">
            {{ heroSubtitle }}
          </p>
          <div class="flex flex-col items-start md:items-end leading-none">
            <span class="clause-label">Editions under test</span>
            <span class="font-mono text-sm text-ink mt-2 tabular-nums">ISO 8601-1:2026 · ISO 8601-2:2026</span>
          </div>
        </div>

        <!-- Massive conformance figure -->
        <div class="mt-16 pt-10 border-t border-rule grid grid-cols-1 md:grid-cols-[auto_1fr] gap-6 md:gap-12 items-end">
          <div
            class="font-display font-light leading-none tabular-nums text-ink select-none"
            style="font-size: clamp(80px, 14vw, 200px); letter-spacing: -0.04em;"
          >
            {{ meanPctDisplay }}<span class="text-accent font-medium">%</span>
          </div>
          <div class="pb-3 md:pb-6">
            <div class="clause-label mb-2">Mean conformance</div>
            <div class="text-ink-soft text-sm md:text-base max-w-sm leading-relaxed">
              Weighted pass rate across {{ libs.length }} implementations and {{ reqs.length }} requirements, scoped to declared conformance classes only.
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ── § 01 — At a glance ────────────────────────────────────────── -->
    <section class="mb-16 md:mb-20">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">At a glance</h2>
        <span class="section-meta">summary statistics</span>
      </div>

      <div class="grid grid-cols-2 md:grid-cols-5 gap-px bg-rule">
        <div class="surface-2 p-6 md:p-8 bg-surface">
          <div class="clause-label mb-3">Requirements</div>
          <div class="stat-figure">{{ reqs.length }}</div>
          <div class="font-mono text-xs text-ink-muted mt-3 tabular-nums">
            {{ baseReqCount }} base · {{ profileReqCount }} profile-specific
          </div>
        </div>
        <div class="surface-2 p-6 md:p-8 bg-surface">
          <div class="clause-label mb-3">Test cases</div>
          <div class="stat-figure">{{ uniqueTestCount }}</div>
          <div class="font-mono text-xs text-ink-muted mt-3 tabular-nums">
            {{ familyCount }} families · {{ libs.length }} versions
          </div>
        </div>
        <div class="surface-2 p-6 md:p-8 bg-surface">
          <div class="clause-label mb-3">Best pass rate</div>
          <div class="stat-figure text-jade">{{ bestPassPct }}<span class="text-2xl">%</span></div>
          <div class="font-mono text-xs text-ink-muted mt-3">highest scoring version</div>
        </div>
        <div class="surface-2 p-6 md:p-8 bg-surface">
          <div class="clause-label mb-3">Profiles</div>
          <div class="stat-figure">{{ profiles.length }}</div>
          <div class="font-mono text-xs text-ink-muted mt-3">RFC 3339 · W3C · EDTF · …</div>
        </div>
        <div v-if="stabilitySummary" class="surface-2 p-6 md:p-8 bg-surface">
          <div class="clause-label mb-3">Version stability</div>
          <div class="stat-figure tabular-nums">
            <span class="text-jade">{{ stabilitySummary.stable }}</span><span class="text-ink-faint">/{{ stabilitySummary.total }}</span>
          </div>
          <div class="font-mono text-xs mt-3 tabular-nums"
            :class="stabilitySummary.divergentTests > 0 ? 'text-amber' : 'text-ink-muted'">
            <template v-if="stabilitySummary.divergentTests === 0">no cross-version divergence</template>
            <template v-else>{{ stabilitySummary.divergentTests }} tests diverge · {{ stabilitySummary.divergentFamilies }} famil{{ stabilitySummary.divergentFamilies === 1 ? 'y' : 'ies' }}</template>
          </div>
        </div>
      </div>
    </section>

    <!-- ── § 02 — Implementations ────────────────────────────────────── -->
    <section class="mb-16 md:mb-20">
      <div class="section-header">
        <span class="section-number">§ 02</span>
        <h2 class="section-title">Implementations under test</h2>
        <button @click="emit('navigate', '/implementations')"
          class="section-meta hover:text-accent transition-colors cursor-pointer">
          view all →
        </button>
      </div>

      <div class="divide-y divide-rule">
        <div v-for="group in families" :key="group.family" class="py-6 first:pt-0">
          <!-- Family header -->
          <div class="flex items-center gap-4 mb-5">
            <img :src="group.logo" :alt="group.family" class="w-10 h-10 shrink-0" />
            <div class="flex-1 min-w-0">
              <div class="flex items-baseline gap-3 flex-wrap">
                <h3 class="font-display text-2xl font-medium text-ink leading-none">{{ group.family }}</h3>
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
            <!-- Stability pill -->
            <div v-if="fsFor(group.family)" class="shrink-0">
              <span :class="['stability-pill', `stability-${fsFor(group.family).stability}`]"
                :title="stabilityLabel(fsFor(group.family))">
                <span class="stability-dot"></span>
                <span>{{ stabilityLabel(fsFor(group.family)) }}</span>
              </span>
            </div>
          </div>

          <!-- Version sub-grid -->
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
            <button
              v-for="lib in versionsToShow(group)"
              :key="lib.id"
              :class="['surface surface-hover text-left p-4 cursor-pointer', versionDelta(lib.id, group.family) > 0 ? 'version-divergent' : '']"
              @click="emit('navigate', '/implementation/' + lib.id)"
            >
              <div class="flex items-baseline justify-between mb-3 gap-2">
                <div class="font-display text-xl text-ink leading-none truncate">{{ libVersionLabel(lib) }}</div>
                <div class="flex items-center gap-2 shrink-0">
                  <span v-if="versionDelta(lib.id, group.family) > 0" class="delta-badge">
                    Δ {{ versionDelta(lib.id, group.family) }}
                  </span>
                  <div class="font-mono text-sm tabular-nums"
                    :class="libStatsMap[lib.id].total ? pctTone(libStatsMap[lib.id].pct) : 'text-ink-faint'">
                    {{ libStatsMap[lib.id].pct }}%
                  </div>
                </div>
              </div>
              <div class="cap-bar mb-3">
                <div class="cap-bar-fill"
                  :class="capBarTone(libStatsMap[lib.id].pct)"
                  :style="{ width: libStatsMap[lib.id].pct + '%' }"></div>
              </div>
              <div class="flex flex-wrap gap-x-3 gap-y-0.5 font-mono text-[11px] tabular-nums">
                <span class="text-jade">{{ libStatsMap[lib.id].pass }} pass</span>
                <span class="text-amber">{{ libStatsMap[lib.id].partial }} partial</span>
                <span class="text-rust">{{ libStatsMap[lib.id].fail }} fail</span>
              </div>
              <div
                v-if="(libStatsMap[lib.id].notSupported || 0) > 0 || (libStatsMap[lib.id].notDeclared || 0) > 0"
                class="flex flex-wrap gap-x-3 gap-y-0.5 font-mono text-[11px] text-ink-faint mt-1 tabular-nums"
              >
                <span v-if="(libStatsMap[lib.id].notSupported || 0) > 0">{{ libStatsMap[lib.id].notSupported }} n/s</span>
                <span v-if="(libStatsMap[lib.id].notDeclared || 0) > 0">{{ libStatsMap[lib.id].notDeclared }} n/d</span>
              </div>
            </button>

            <!-- "+N more" card -->
            <button
              v-if="hiddenCount(group) > 0"
              @click="emit('navigate', '/implementations')"
              class="surface surface-hover text-left p-4 cursor-pointer flex flex-col justify-between"
            >
              <div class="font-mono text-xs text-ink-muted uppercase tracking-wider">older versions</div>
              <div class="mt-2 flex items-baseline gap-2">
                <span class="font-display text-2xl text-ink tabular-nums leading-none">+{{ hiddenCount(group) }}</span>
                <span class="font-mono text-xs text-ink-faint">in family</span>
              </div>
              <div class="mt-3 font-mono text-xs text-accent uppercase tracking-wider">view all →</div>
            </button>
          </div>
        </div>
      </div>
    </section>

    <!-- ── § 03 — Profiles ───────────────────────────────────────────── -->
    <section class="mb-16 md:mb-20">
      <div class="section-header">
        <span class="section-number">§ 03</span>
        <h2 class="section-title">Profiles</h2>
        <button @click="emit('navigate', '/profiles')"
          class="section-meta hover:text-accent transition-colors cursor-pointer">
          view all →
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        <button
          v-for="p in profiles"
          :key="p.id"
          class="surface surface-hover text-left p-5 cursor-pointer flex flex-col"
          @click="emit('navigate', '/profile/' + p.id.replace('profile:', ''))"
        >
          <div class="flex items-center gap-3 mb-3">
            <img v-if="p.logo" :src="p.logo" :alt="p.name" class="h-6 w-auto opacity-90" />
            <div class="font-display text-xl text-ink leading-none">{{ p.name }}</div>
          </div>
          <div v-if="p.description" class="text-sm text-ink-muted leading-relaxed mb-4 flex-1">{{ p.description }}</div>
          <div class="flex items-center gap-3">
            <div class="flex-1 cap-bar">
              <div class="cap-bar-fill"
                :class="capBarTone(profilePct(p))"
                :style="{ width: profilePct(p) + '%' }"></div>
            </div>
            <span class="font-mono text-sm tabular-nums" :class="pctTone(profilePct(p))">{{ profilePct(p) }}%</span>
          </div>
        </button>
      </div>
    </section>

    <!-- ── § 04 — Go deeper ──────────────────────────────────────────── -->
    <section>
      <div class="section-header">
        <span class="section-number">§ 04</span>
        <h2 class="section-title">Go deeper</h2>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <button
          @click="emit('navigate', '/matrix')"
          class="surface surface-hover text-left p-6 cursor-pointer group"
        >
          <div class="flex items-center justify-between">
            <div>
              <div class="font-display text-2xl text-ink mb-2">Capability matrix</div>
              <div class="text-sm text-ink-muted">Full requirements × libraries breakdown.</div>
            </div>
            <svg class="w-5 h-5 text-ink-muted group-hover:text-accent transition-colors" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
          </div>
        </button>
        <button
          @click="emit('navigate', '/methodology')"
          class="surface surface-hover text-left p-6 cursor-pointer group"
        >
          <div class="flex items-center justify-between">
            <div>
              <div class="font-display text-2xl text-ink mb-2">Test methodology</div>
              <div class="text-sm text-ink-muted">Parsing, generation, and round-trip testing approaches.</div>
            </div>
            <svg class="w-5 h-5 text-ink-muted group-hover:text-accent transition-colors" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
          </div>
        </button>
      </div>
    </section>
  </div>
</template>
