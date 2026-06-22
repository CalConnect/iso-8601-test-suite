<script setup>
import { computed } from "vue";
import { libStats } from "../composables/useStats";

const props = defineProps({
  libs: { type: Array, required: true },
  reqs: { type: Array, required: true },
});

const emit = defineEmits(["navigate"]);
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Hero -->
    <section class="relative mb-12">
      <div class="iso-watermark hidden md:block">
        <span style="top: 22%; left: 14%;">result:ruby-date</span>
        <span style="top: 62%; right: 18%;">yaml · v1</span>
        <span style="top: 80%; left: 42%;">conf-test:*</span>
      </div>
      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 00</span>
          <span class="clause-label">Machine-readable output</span>
        </div>
        <h1 class="display-hero text-4xl md:text-6xl mb-4">
          Test <em>reports</em>.
        </h1>
        <p class="text-ink-soft text-base md:text-lg max-w-2xl leading-relaxed">
          Each implementation ships a complete YAML conformance report — every requirement, every test case, every actual value.
          Download and inspect offline.
        </p>
      </div>
    </section>

    <!-- Reports grid -->
    <section>
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">Per-implementation reports</h2>
        <span class="section-meta">{{ libs.length }} YAML files</span>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        <div
          v-for="lib in libs"
          :key="lib.id"
          class="surface p-5"
        >
          <div class="flex items-center gap-3 mb-5 pb-4 border-b border-rule-soft">
            <img :src="lib.logo" :alt="lib.name" class="w-9 h-9" />
            <div class="flex-1 min-w-0">
              <div class="font-display text-base text-ink truncate">{{ lib.name }}</div>
              <div class="font-mono text-xs text-ink-faint">{{ lib.language }} {{ lib.version }}</div>
            </div>
          </div>

          <div class="grid grid-cols-4 gap-px bg-rule mb-5">
            <div class="bg-surface p-2 text-center">
              <div class="stat-figure text-xl text-jade">{{ libStats(lib, reqs).pass }}</div>
              <div class="clause-label mt-1">Pass</div>
            </div>
            <div class="bg-surface p-2 text-center">
              <div class="stat-figure text-xl text-amber">{{ libStats(lib, reqs).partial }}</div>
              <div class="clause-label mt-1">Partial</div>
            </div>
            <div class="bg-surface p-2 text-center">
              <div class="stat-figure text-xl text-rust">{{ libStats(lib, reqs).fail }}</div>
              <div class="clause-label mt-1">Fail</div>
            </div>
            <div class="bg-surface p-2 text-center">
              <div class="stat-figure text-xl text-ink">{{ libStats(lib, reqs).total }}</div>
              <div class="clause-label mt-1">Total</div>
            </div>
          </div>

          <a
            :href="'/results/' + lib.id + '.yaml'"
            download
            class="btn-ghost w-full justify-center text-xs no-underline"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M12 3v12m0 0l-4-4m4 4l4-4M5 21h14"/></svg>
            Download {{ lib.id }}.yaml
          </a>
        </div>
      </div>
    </section>
  </div>
</template>
