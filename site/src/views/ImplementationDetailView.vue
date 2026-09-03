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

const BASE = import.meta.env.BASE_URL;

const stats = computed(() => libStats(props.lib, props.reqs));

const targetIds = computed(() => new Set((props.lib.target_profiles || []).map(p => p.id)));

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
    const targeted = targetIds.value.has(p.id);
    return { ...p, adapterResult: ar, det, pass, total, pct: total ? Math.round(pass / total * 100) : 0, targeted };
  });
});

const implementedProfiles = computed(() => profileData.value.filter(p => p.targeted));
const otherProfiles = computed(() => profileData.value.filter(p => !p.targeted));

function openReport(p) {
  const profileId = p.id.startsWith("profile:") ? p.id.replace("profile:", "") : p.id;
  emit("navigate", `/implementation/${props.lib.id}/report/${profileId}`);
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

const qualificationNotes = computed(() => props.lib.qualification_notes || []);

const noteCategoryLabel = (cat) =>
  cat === "output-postprocessing" ? "Output post-processing"
  : cat === "input-preprocessing" ? "Input pre-processing"
  : cat;
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/implementations')" class="clause-label hover:text-accent transition-colors">Implementations</button>
      <svg v-if="lib.family" class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button v-if="lib.family" @click="emit('navigate', '/implementations')" class="clause-label hover:text-accent transition-colors">{{ lib.family }}</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">{{ lib.name }}</span>
    </div>

    <!-- Header -->
    <div class="flex items-start gap-6 mb-10 pb-8 border-b border-rule">
      <img :src="lib.logo" :alt="lib.name" class="w-16 h-16" />
      <div class="flex-1 min-w-0">
        <div v-if="lib.family" class="clause-label mb-1.5">Part of: {{ lib.family }}</div>
        <h1 class="display-hero text-4xl md:text-5xl mb-1">{{ lib.name }}</h1>
        <div class="font-mono text-sm text-ink-muted">{{ lib.language }} · {{ lib.version }}</div>
        <div class="mt-3">
          <a
            :href="BASE + 'results/' + lib.id + '.yaml'"
            download
            class="btn-ghost text-xs"
          >
            Download YAML Results
            <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>
          </a>
        </div>
      </div>
    </div>

    <!-- Qualification notes (Tier 2 workarounds) -->
    <div v-if="qualificationNotes.length > 0" class="mb-10 surface p-5 md:p-6">
      <div class="flex items-baseline gap-3 mb-4">
        <span class="clause-label clause-label-accent">Qualification notes</span>
        <span class="font-mono text-xs text-ink-faint tabular-nums">{{ qualificationNotes.length }}</span>
      </div>
      <p class="text-sm text-ink-muted mb-4 max-w-3xl leading-relaxed">
        These are workarounds the adapter applies around the library to compensate
        for upstream gaps (e.g. rewriting <code class="font-mono text-ink">Z</code>
        to a numeric UTC offset before parsing). They are declared transparently —
        the library itself is not modified, only the input/output flowing through it.
      </p>
      <ul class="space-y-4">
        <li v-for="(note, idx) in qualificationNotes" :key="idx" class="grid grid-cols-[auto,1fr] gap-x-4">
          <div class="pt-0.5">
            <span class="pill pill-info whitespace-nowrap">{{ noteCategoryLabel(note.category) }}</span>
          </div>
          <div class="min-w-0">
            <div class="font-display text-base text-ink mb-1">{{ note.summary }}</div>
            <p class="text-sm text-ink-muted leading-relaxed">{{ note.detail }}</p>
          </div>
        </li>
      </ul>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-3 md:grid-cols-6 gap-px bg-rule mb-10">
      <div class="bg-surface p-4 md:p-5 text-center">
        <div class="stat-figure text-2xl md:text-3xl">{{ stats.total }}</div>
        <div class="clause-label mt-2">Capabilities</div>
      </div>
      <div class="bg-surface p-4 md:p-5 text-center">
        <div class="stat-figure text-2xl md:text-3xl text-jade">{{ stats.pass }}</div>
        <div class="clause-label mt-2">Passed</div>
      </div>
      <div class="bg-surface p-4 md:p-5 text-center">
        <div class="stat-figure text-2xl md:text-3xl text-amber">{{ stats.partial }}</div>
        <div class="clause-label mt-2">Partial</div>
      </div>
      <div class="bg-surface p-4 md:p-5 text-center">
        <div class="stat-figure text-2xl md:text-3xl text-rust">{{ stats.fail }}</div>
        <div class="clause-label mt-2">Failed</div>
      </div>
      <div class="bg-surface p-4 md:p-5 text-center">
        <div class="stat-figure text-2xl md:text-3xl text-ink-faint">{{ stats.notSupported || 0 }}</div>
        <div class="clause-label mt-2">Not Supported</div>
      </div>
      <div class="bg-surface p-4 md:p-5 text-center">
        <div class="stat-figure text-2xl md:text-3xl">{{ stats.pct }}<span class="text-base">%</span></div>
        <div class="clause-label mt-2">Pass Rate</div>
      </div>
    </div>

    <!-- Implemented profiles -->
    <div class="mb-12" v-if="implementedProfiles.length > 0">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">Implemented profiles</h2>
        <span class="section-meta">{{ implementedProfiles.length }} declared</span>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
        <button
          v-for="p in implementedProfiles"
          :key="p.id"
          @click="openReport(p)"
          class="surface surface-hover text-left p-4 cursor-pointer"
        >
          <div class="flex items-center gap-2 mb-3">
            <img v-if="p.logo" :src="p.logo" :alt="p.name" class="w-5 h-5 opacity-90" />
            <div class="font-display text-lg text-ink">{{ p.name }}</div>
          </div>
          <div class="mb-3">
            <span :class="['pill', detClass(p.det)]">{{ detLabel(p.det) }}</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="flex-1 cap-bar">
              <div class="cap-bar-fill"
                :class="pctBarTone(p.pct)"
                :style="{ width: p.pct + '%' }"></div>
            </div>
            <span class="font-mono text-xs tabular-nums" :class="pctTone(p.pct)">{{ p.pct }}%</span>
          </div>
          <div class="font-mono text-[11px] text-ink-faint mt-2 tabular-nums">{{ p.pass }}/{{ p.total }} tests</div>
        </button>
      </div>
    </div>

    <!-- Other profiles (not implemented) -->
    <div v-if="otherProfiles.length > 0">
      <div class="section-header">
        <span class="section-number">§ 02</span>
        <h2 class="section-title">Not implemented</h2>
        <span class="section-meta">{{ otherProfiles.length }} profile{{ otherProfiles.length === 1 ? '' : 's' }} not declared</span>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
        <div
          v-for="p in otherProfiles"
          :key="p.id"
          class="surface p-4 opacity-50"
        >
          <div class="flex items-center gap-2 mb-3">
            <img v-if="p.logo" :src="p.logo" :alt="p.name" class="w-5 h-5 opacity-50" />
            <div class="font-display text-lg text-ink-muted">{{ p.name }}</div>
          </div>
          <span class="pill pill-muted">Not declared</span>
          <div class="font-mono text-[11px] text-ink-faint mt-3 leading-relaxed">
            Not part of this implementation's declared conformance.
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
