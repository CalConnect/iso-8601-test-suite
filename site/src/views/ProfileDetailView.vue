<script setup>
import { computed, ref } from "vue";
import { statusColor, statusBg, statusIcon, statusLabel } from "../composables/useStatus";
import { trunc } from "../composables/useFormat";
import { overallDetermination } from "../composables/useStats";

const props = defineProps({
  profile: { type: Object, required: true },
  libs: { type: Array, required: true },
});

const emit = defineEmits(["open-detail", "navigate"]);

const expandedReqs = ref(new Set());
const expandedTests = ref(new Set());

function toggleReq(reqId) {
  const s = new Set(expandedReqs.value);
  s.has(reqId) ? s.delete(reqId) : s.add(reqId);
  expandedReqs.value = s;
}

function toggleTest(testId) {
  const s = new Set(expandedTests.value);
  s.has(testId) ? s.delete(testId) : s.add(testId);
  expandedTests.value = s;
}

function overallDetLabel(det) {
  if (det === "full") return { label: "Fully Compliant", cls: "pill pill-pass" };
  if (det === "partial") return { label: "Partially Compliant", cls: "pill pill-partial" };
  return { label: "Not Implemented", cls: "pill pill-muted" };
}

function libDet(libId) {
  const statuses = props.profile.traceability?.flatMap(cc =>
    cc.requirements.flatMap(r => r.per_library)
  ).filter(pl => pl?.library_id === libId).map(pl => pl.status).filter(Boolean) || [];
  return overallDetermination(statuses);
}

const totalReqs = computed(() => {
  return props.profile.traceability?.reduce((sum, cc) => sum + cc.requirements.length, 0) || 0;
});

const totalTests = computed(() => {
  return props.profile.traceability?.reduce((sum, cc) =>
    sum + cc.requirements.reduce((s, r) => s + r.tests.length, 0), 0) || 0;
});
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/profiles')" class="clause-label hover:text-accent transition-colors">Profiles</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">{{ profile.name }}</span>
    </div>

    <!-- Header -->
    <div class="flex items-start gap-6 mb-10 pb-8 border-b border-rule">
      <div v-if="profile.logo" class="shrink-0">
        <img :src="profile.logo" :alt="profile.name" class="h-16 w-auto" />
      </div>
      <div class="flex-1 min-w-0">
        <h1 class="display-hero text-4xl md:text-5xl mb-2">{{ profile.name }}</h1>
        <div class="font-mono text-xs text-ink-faint mb-3">{{ profile.id }}</div>
        <p v-if="profile.description" class="text-ink-soft text-base leading-relaxed max-w-2xl mb-4">{{ profile.description }}</p>
        <div v-if="profile.source?.length" class="flex flex-wrap gap-2">
          <template v-for="src in profile.source" :key="src">
            <a v-if="src.startsWith('http')" :href="src" target="_blank"
              class="btn-ghost text-xs">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
              {{ src.replace(/^https?:\/\//, '').split('/').slice(0, 2).join('/') }}
            </a>
            <span v-else class="font-mono text-xs text-ink-muted border border-rule px-2 py-1">
              {{ src.replace(/^urn:/, '').split(':').slice(0, 3).join(':') }}
            </span>
          </template>
        </div>
      </div>
    </div>

    <!-- Summary cards -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-px bg-rule mb-12">
      <div class="bg-surface p-5 text-center">
        <div class="stat-figure text-3xl">{{ profile.traceability?.length || 0 }}</div>
        <div class="clause-label mt-2">Traceability Classes</div>
      </div>
      <div class="bg-surface p-5 text-center">
        <div class="stat-figure text-3xl">{{ totalReqs }}</div>
        <div class="clause-label mt-2">Requirements</div>
      </div>
      <div class="bg-surface p-5 text-center">
        <div class="stat-figure text-3xl">{{ totalTests }}</div>
        <div class="clause-label mt-2">Test Cases</div>
      </div>
      <div class="bg-surface p-5 text-center">
        <div class="stat-figure text-3xl">{{ (profile.additional_requirements || []).length }}</div>
        <div class="clause-label mt-2">Additional Reqs</div>
      </div>
    </div>

    <!-- Library summary -->
    <section class="mb-12">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">Library compliance summary</h2>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <button
          v-for="ar in profile.adapter_results"
          :key="ar.id"
          @click="emit('navigate', '/implementation/' + ar.id)"
          class="surface surface-hover p-5 text-left cursor-pointer"
        >
          <div class="flex items-center gap-2 mb-3">
            <img :src="libs.find(l => l.id === ar.id)?.logo" :alt="ar.id" class="w-6 h-6" />
            <div class="font-display text-lg text-ink flex-1">{{ libs.find(l => l.id === ar.id)?.name || ar.id }}</div>
            <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
          </div>
          <div class="mb-3">
            <span :class="overallDetLabel(libDet(ar.id)).cls">
              {{ overallDetLabel(libDet(ar.id)).label }}
            </span>
          </div>
          <div class="flex gap-4 font-mono text-xs tabular-nums">
            <span class="text-jade">{{ ar.test_pass }}/{{ ar.test_total }} pass</span>
            <span class="text-amber">{{ ar.req_partial }} partial</span>
            <span class="text-rust">{{ ar.req_fail }} fail</span>
            <span v-if="ar.req_not_supported" class="text-ink-faint">{{ ar.req_not_supported }} n/s</span>
          </div>
        </button>
      </div>
    </section>

    <!-- Additional requirements -->
    <section v-if="profile.additional_requirements?.length" class="mb-12">
      <div class="section-header">
        <span class="section-number">§ 02</span>
        <h2 class="section-title">Profile-specific requirements</h2>
      </div>
      <div class="space-y-2">
        <div
          v-for="ar in profile.additional_requirements"
          :key="ar.id"
          class="surface surface-hover p-4 cursor-pointer"
          @click="emit('navigate', '/requirement/' + ar.id.replace('req:', ''))"
        >
          <div class="font-mono text-sm text-accent mb-1">{{ ar.id }}</div>
          <div class="text-sm text-ink-muted leading-relaxed">{{ ar.statement }}</div>
        </div>
      </div>
    </section>

    <!-- Traceability -->
    <section>
      <div class="section-header">
        <span class="section-number">§ 03</span>
        <h2 class="section-title">Requirements &amp; test results</h2>
      </div>
      <div class="space-y-2">
        <div v-for="cc in profile.traceability" :key="cc.id" class="surface overflow-hidden">
          <div class="px-5 py-3 surface-2 border-b border-rule flex items-center justify-between">
            <div>
              <span class="font-mono text-xs text-accent">{{ cc.id }}</span>
              <span class="clause-label ml-3">{{ cc.requirements.length }} requirements</span>
            </div>
          </div>

          <div class="divide-y divide-rule-soft">
            <div v-for="req in cc.requirements" :key="req.requirement_id" class="px-5 py-3">
              <button class="w-full text-left flex items-start gap-3" @click="toggleReq(req.requirement_id)">
                <svg class="w-3.5 h-3.5 mt-1 shrink-0 transition-transform text-ink-faint" :class="{ 'rotate-90': expandedReqs.has(req.requirement_id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 flex-wrap mb-1">
                    <span v-if="req.section" class="font-mono text-xs text-accent border border-accent/40 px-1.5 py-0.5">{{ req.section }}</span>
                    <button @click.stop="emit('navigate', '/requirement/' + req.requirement_id.replace('req:', ''))"
                      class="font-mono text-sm text-ink hover:text-accent transition-colors">{{ req.requirement_id.replace('req:', '') }}</button>
                    <span class="clause-label">{{ req.tests.length }} tests</span>
                  </div>
                  <div v-if="req.statement" class="text-sm text-ink-muted leading-snug">{{ trunc(req.statement, 200) }}</div>
                  <div class="flex flex-wrap gap-1.5 mt-2">
                    <span v-for="pl in req.per_library" :key="pl.library_id"
                      :class="['pill', statusBg(pl.status)]">
                      <span>{{ statusIcon(pl.status) }}</span>
                      <span>{{ statusLabel(pl.status) }}</span>
                    </span>
                  </div>
                </div>
              </button>

              <div v-if="expandedReqs.has(req.requirement_id)" class="mt-3 ml-7 space-y-2">
                <div v-for="test in req.tests" :key="test.test_id" class="surface overflow-hidden">
                  <button class="w-full text-left px-4 py-2.5 flex items-center gap-2" @click="toggleTest(test.test_id)">
                    <svg class="w-3 h-3 shrink-0 transition-transform text-ink-faint" :class="{ 'rotate-90': expandedTests.has(test.test_id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                    <span class="font-mono text-xs text-ink">{{ test.test_id.replace('conf-test:', '') }}</span>
                    <span class="text-ink-faint">·</span>
                    <span class="text-xs text-ink-muted flex-1 truncate">{{ test.description || test.test_type }}</span>
                    <span class="micro-tag">{{ test.test_type }}</span>
                  </button>

                  <div v-if="expandedTests.has(test.test_id)" class="px-4 pb-3 border-t border-rule-soft">
                    <div class="mt-2 surface-2 p-3 font-mono text-sm space-y-2">
                      <div v-if="test.given?.expression">
                        <div class="clause-label mb-0.5">Input</div>
                        <div class="text-steel">{{ test.given.expression }}</div>
                      </div>
                      <div v-if="test.given?.expression_a">
                        <div class="clause-label mb-0.5">Input</div>
                        <div class="text-steel">{{ test.given.expression_a }} ≡ {{ test.given.expression_b }}</div>
                      </div>
                      <div v-if="test.given?.components">
                        <div class="clause-label mb-0.5">Components</div>
                        <pre class="text-steel/80 text-xs whitespace-pre-wrap">{{ JSON.stringify(test.given.components, null, 2) }}</pre>
                      </div>
                      <div v-if="test.expect?.expression">
                        <div class="clause-label mb-0.5">Expected</div>
                        <div class="text-jade">{{ test.expect.expression }}</div>
                      </div>
                      <div v-if="test.expect?.valid !== undefined && !test.expect?.expression">
                        <div class="clause-label mb-0.5">Expected</div>
                        <pre class="text-jade/80 text-xs whitespace-pre-wrap">{{ JSON.stringify(test.expect, null, 2) }}</pre>
                      </div>
                    </div>

                    <div class="mt-2 space-y-1">
                      <div v-for="pl in req.per_library" :key="pl.library_id" class="flex items-center gap-2">
                        <img :src="libs.find(l => l.id === pl.library_id)?.logo" :alt="pl.library_id" class="w-4 h-4" />
                        <span class="font-mono text-xs text-ink-muted w-24 truncate">{{ libs.find(l => l.id === pl.library_id)?.name?.split(' ').slice(0, 2).join(' ') }}</span>
                        <template v-for="detail in pl.details.filter(d => d.test_id === test.test_id)" :key="detail.test_id">
                          <span class="text-sm" :class="statusColor(detail.result)">{{ statusIcon(detail.result) }}</span>
                          <span class="font-mono text-xs text-ink-muted">{{ detail.result }}</span>
                          <span v-if="detail.actual" class="font-mono text-xs text-ink-faint truncate max-w-[200px]">{{ JSON.stringify(detail.actual) }}</span>
                          <span v-if="detail.notes" class="font-mono text-xs text-amber truncate max-w-[200px]">{{ detail.notes }}</span>
                        </template>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
