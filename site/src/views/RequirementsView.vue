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

function pctTone(pct) {
  if (pct >= 60) return "text-jade";
  if (pct >= 30) return "text-amber";
  return "text-rust";
}

const standards = computed(() => [
  {
    slug: "iso-8601-1",
    label: "Part 1",
    title: "ISO 8601-1:2026",
    subtitle: "Representations",
    description: "Calendar dates, ordinal dates, week dates, time of day, date-time combinations, time intervals, durations, and recurring time intervals.",
    ...statsFor(r => r.part === "1"),
  },
  {
    slug: "iso-8601-2",
    label: "Part 2",
    title: "ISO 8601-2:2026",
    subtitle: "Extensions",
    description: "Extended time intervals, grouped time scale units, set representation, qualification of uncertainty, seasons, date-time selection, arithmetic, and more.",
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
    ...s,
  };
}));
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Hero -->
    <section class="relative mb-12">
      <div class="iso-watermark hidden md:block">
        <span style="top: 14%; left: 12%;">§ 5.2.2.1</span>
        <span style="top: 58%; right: 16%;">iso:8601:-1:ed-1:en</span>
        <span style="top: 78%; left: 38%;">req-class:date-cal</span>
      </div>
      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 00</span>
          <span class="clause-label">Normative reference</span>
        </div>
        <h1 class="display-hero text-4xl md:text-6xl mb-4">
          ISO 8601 <em>requirements</em>.
        </h1>
        <p class="text-ink-soft text-base md:text-lg max-w-2xl leading-relaxed">
          {{ reqs.length }} normative requirements from ISO 8601-1, ISO 8601-2, and registered profiles.
          Select a section to browse.
        </p>
      </div>
    </section>

    <!-- ISO Standards -->
    <section class="mb-12">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">ISO standards</h2>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <button
          v-for="s in standards"
          :key="s.slug"
          @click="emit('navigate', '/requirements/' + s.slug)"
          class="surface surface-hover text-left p-6 cursor-pointer"
        >
          <div class="flex items-baseline gap-3 mb-3">
            <span class="font-mono text-xs text-accent border border-accent/40 px-2 py-0.5">{{ s.label }}</span>
            <span class="clause-label">{{ s.subtitle }}</span>
          </div>
          <h3 class="font-display text-3xl text-ink mb-2">{{ s.title }}</h3>
          <p class="text-sm text-ink-muted leading-relaxed mt-2 mb-4">{{ s.description }}</p>
          <div class="flex items-center gap-3 mb-2">
            <span class="font-display text-2xl tabular-nums text-ink">{{ s.count }}</span>
            <span class="clause-label">requirements</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="flex-1 cap-bar">
              <div class="cap-bar-fill"
                :class="pctBarColor(s.pct).replace('bg-', '')"
                :style="{ width: s.pct + '%' }"></div>
            </div>
            <span class="font-mono text-sm tabular-nums" :class="pctTone(s.pct)">{{ s.pct }}%</span>
          </div>
        </button>
      </div>
    </section>

    <!-- Profiles -->
    <section>
      <div class="section-header">
        <span class="section-number">§ 02</span>
        <h2 class="section-title">Profiles</h2>
        <span class="section-meta">{{ profileCards.length }} subsets</span>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        <button
          v-for="p in profileCards"
          :key="p.slug"
          @click="emit('navigate', '/requirements/' + p.slug)"
          class="surface surface-hover text-left p-4 cursor-pointer"
        >
          <div class="flex items-center gap-2 mb-3">
            <img v-if="p.logo" :src="p.logo" :alt="p.label" class="w-5 h-5 opacity-90" />
            <span class="font-display text-base text-ink truncate">{{ p.label }}</span>
          </div>
          <p class="text-xs text-ink-muted leading-relaxed line-clamp-2 mb-3">{{ p.description }}</p>
          <div class="flex items-center gap-2">
            <span class="font-mono text-base tabular-nums text-ink">{{ p.count }}</span>
            <span class="clause-label">reqs</span>
            <div class="flex-1"></div>
            <div class="w-12 cap-bar">
              <div class="cap-bar-fill"
                :class="pctBarColor(p.pct).replace('bg-', '')"
                :style="{ width: p.pct + '%' }"></div>
            </div>
            <span class="font-mono text-xs tabular-nums" :class="pctTone(p.pct)">{{ p.pct }}%</span>
          </div>
        </button>
      </div>
    </section>
  </div>
</template>
