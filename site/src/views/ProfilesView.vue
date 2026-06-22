<script setup>
import { profilePct } from "../composables/useStats";
import { trunc, libShortName } from "../composables/useFormat";
import { computed } from "vue";

const props = defineProps({
  profiles: { type: Array, required: true },
  libs: { type: Array, required: true },
});

const emit = defineEmits(["navigate"]);

const sortedProfiles = computed(() => {
  const iso = props.profiles.filter(p => p.id.startsWith("profile:iso-8601"));
  const rest = props.profiles.filter(p => !p.id.startsWith("profile:iso-8601"));
  return [...iso, ...rest];
});

function pctTone(pct) {
  if (pct >= 40) return "text-jade";
  if (pct >= 15) return "text-amber";
  return "text-rust";
}

function pctBarTone(pct) {
  if (pct >= 40) return "pass";
  if (pct >= 15) return "partial";
  return "fail";
}

function reqCount(p) {
  return p.traceability_class_count || p.traceability?.length || 0;
}

function testCount(p) {
  return p.traceability?.reduce((sum, cc) => sum + cc.requirements.reduce((s, r) => s + r.tests.length, 0), 0) || 0;
}
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Hero -->
    <section class="relative mb-12">
      <div class="iso-watermark hidden md:block">
        <span style="top: 18%; left: 8%;">RFC 3339</span>
        <span style="top: 60%; right: 14%;">EDTF · L2</span>
        <span style="top: 84%; left: 36%;">W3C Datetime</span>
      </div>
      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 01</span>
          <span class="clause-label">Subset definitions</span>
        </div>
        <h1 class="display-hero text-4xl md:text-6xl mb-4">
          ISO 8601 <em>profiles</em>.
        </h1>
        <p class="text-ink-soft text-base md:text-lg max-w-2xl leading-relaxed">
          {{ profiles.length }} profiles defined under ISO 8601, each representing
          a specific subset of requirements for targeted use cases.
        </p>
      </div>
    </section>

    <!-- Profile selection guidance -->
    <section class="mb-12">
      <div class="section-header">
        <span class="section-number">§ 02</span>
        <h2 class="section-title">Choose by use case</h2>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div class="surface p-5">
          <div class="clause-label mb-3">Web &amp; Internet</div>
          <div class="text-sm text-ink-soft leading-relaxed space-y-1">
            <button @click="emit('navigate', '/profile/rfc-3339')" class="block text-accent hover:underline">RFC 3339</button>
            <span class="text-ink-muted text-xs"> — APIs, protocols</span>
            <button @click="emit('navigate', '/profile/w3c-datetime')" class="block text-accent hover:underline">W3C Datetime</button>
            <span class="text-ink-muted text-xs"> — HTML metadata</span>
          </div>
        </div>
        <div class="surface p-5">
          <div class="clause-label mb-3">Libraries &amp; Archives</div>
          <div class="text-sm text-ink-soft leading-relaxed space-y-1">
            <button @click="emit('navigate', '/profile/edtf-level-0')" class="block text-accent hover:underline">EDTF 0</button>
            <span class="text-ink-muted text-xs"> — basic extended dates</span>
            <button @click="emit('navigate', '/profile/edtf-level-1')" class="block text-accent hover:underline">EDTF 1</button>
            <span class="text-ink-muted text-xs"> — uncertain / approximate</span>
            <button @click="emit('navigate', '/profile/edtf-level-2')" class="block text-accent hover:underline">EDTF 2</button>
            <span class="text-ink-muted text-xs"> — structured expressions</span>
          </div>
        </div>
        <div class="surface p-5">
          <div class="clause-label mb-3">Full compliance</div>
          <div class="text-sm text-ink-soft leading-relaxed space-y-1">
            <button @click="emit('navigate', '/profile/iso-8601-1-basic-format')" class="block text-accent hover:underline">Basic Format</button>
            <span class="text-ink-muted text-xs"> — compact storage</span>
            <button @click="emit('navigate', '/profile/iso-8601-1-complete')" class="block text-accent hover:underline">ISO 8601-1</button>
            <span class="text-ink-muted text-xs"> — full Part 1</span>
            <button @click="emit('navigate', '/profile/iso-8601-2-complete')" class="block text-accent hover:underline">ISO 8601-2</button>
            <span class="text-ink-muted text-xs"> — full Part 1 + 2</span>
          </div>
        </div>
      </div>
    </section>

    <!-- All profiles -->
    <section>
      <div class="section-header">
        <span class="section-number">§ 03</span>
        <h2 class="section-title">All profiles</h2>
        <span class="section-meta">{{ sortedProfiles.length }} entries</span>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <button
          v-for="p in sortedProfiles"
          :key="p.id"
          class="surface surface-hover text-left p-6 cursor-pointer flex flex-col"
          @click="emit('navigate', '/profile/' + p.id.replace('profile:', ''))"
        >
          <div class="flex items-start justify-between gap-3 mb-4">
            <div class="flex items-center gap-3 min-w-0">
              <img v-if="p.logo" :src="p.logo" :alt="p.name" class="h-7 w-auto opacity-90 shrink-0" />
              <div class="min-w-0">
                <div class="font-display text-xl text-ink leading-tight truncate">{{ p.name }}</div>
                <div class="font-mono text-xs text-ink-faint mt-0.5 truncate">{{ p.id }}</div>
              </div>
            </div>
            <div class="text-right shrink-0">
              <div class="font-display text-2xl tabular-nums leading-none" :class="pctTone(profilePct(p))">{{ profilePct(p) }}%</div>
              <div class="clause-label mt-1">best lib</div>
            </div>
          </div>

          <p v-if="p.description" class="text-sm text-ink-muted leading-relaxed mb-4 flex-1">{{ trunc(p.description, 220) }}</p>

          <div class="flex flex-wrap gap-x-4 gap-y-1 font-mono text-xs text-ink-faint mb-4 tabular-nums">
            <span>{{ reqCount(p) }} classes</span>
            <span>{{ testCount(p) }} tests</span>
            <span>{{ (p.additional_requirements || []).length }} add'l reqs</span>
          </div>

          <div class="space-y-1.5">
            <div v-for="ar in p.adapter_results" :key="ar.id" class="flex items-center gap-3">
              <span class="w-32 font-mono text-xs text-ink-muted truncate shrink-0">
                {{ libs.find(l => l.id === ar.id)?.name?.split(' ').slice(0, 2).join(' ') || ar.id }}
              </span>
              <div class="flex-1 cap-bar">
                <div class="cap-bar-fill"
                  :class="pctBarTone(ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0)"
                  :style="{ width: (ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0) + '%' }"></div>
              </div>
              <span class="font-mono text-xs tabular-nums w-10 text-right shrink-0"
                :class="pctTone(ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0)">
                {{ ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0 }}%
              </span>
            </div>
          </div>
        </button>
      </div>
    </section>
  </div>
</template>
