<script setup>
import { ref, computed } from "vue";
import CapabilityBadge from "../components/CapabilityBadge.vue";
import { statusColor, statusBg, statusIcon } from "../composables/useStatus";
import { pctBarColor } from "../composables/useStats";
import { fmtTag, capTypeLabel, trunc, groupByFamily, libVersionLabel } from "../composables/useFormat";

const props = defineProps({
  libs: { type: Array, required: true },
  reqs: { type: Array, required: true },
  categories: { type: Array, required: true },
  profiles: { type: Array, required: true },
});

const emit = defineEmits(["open-detail"]);

const cat = ref(null);
const profileFilter = ref(null);
const q = ref("");
const expanded = ref(new Set());

function toggleExpand(rid) {
  const s = new Set(expanded.value);
  s.has(rid) ? s.delete(rid) : s.add(rid);
  expanded.value = s;
}

const families = computed(() => groupByFamily(props.libs));

const familyStartIds = computed(() => {
  const s = new Set();
  families.value.forEach(g => { if (g.versions[0]) s.add(g.versions[0].id); });
  return s;
});

const familyStats = computed(() => {
  const map = {};
  for (const lib of props.libs) {
    const key = lib.family || lib.language || "Other";
    map[key] ??= { pass: 0, total: 0 };
    for (const r of props.reqs) {
      const caps = r.tests?.[lib.id];
      if (!caps) continue;
      for (const cap of Object.values(caps)) {
        map[key].total++;
        if (cap.status === "pass") map[key].pass++;
      }
    }
  }
  for (const k of Object.keys(map)) {
    const { pass, total } = map[k];
    map[k].pct = total ? Math.round(pass / total * 100) : 0;
  }
  return map;
});

function pctTextColor(pct) {
  return pctBarColor(pct).replace("bg-", "text-");
}

function pctBorderColor(pct) {
  return pctBarColor(pct).replace("bg-", "border-");
}

const filtered = computed(() => {
  let out = props.reqs;
  if (cat.value) out = out.filter(r => r.category === cat.value);
  if (profileFilter.value) {
    const pid = profileFilter.value;
    out = out.filter(r => r.profiles?.some(p => p.id === pid) || r.source_profile === pid);
  }
  if (q.value) {
    const ql = q.value.toLowerCase();
    out = out.filter(r =>
      r.id.toLowerCase().includes(ql) ||
      (r.section && r.section.toLowerCase().includes(ql)) ||
      (r.statement && r.statement.toLowerCase().includes(ql)) ||
      (r.pattern && r.pattern.toLowerCase().includes(ql))
    );
  }
  return out;
});

const grouped = computed(() => {
  const m = {};
  filtered.value.forEach(r => {
    const c = r.category || "Other";
    (m[c] ??= []).push(r);
  });
  return m;
});

const totalStats = computed(() => {
  let pass = 0, partial = 0, fail = 0, notSupported = 0, total = 0;
  props.reqs.forEach(r => {
    props.libs.forEach(l => {
      const caps = r.tests?.[l.id];
      if (!caps) return;
      Object.values(caps).forEach(c => {
        total++;
        if (c.status === "pass") pass++;
        else if (c.status === "partial") partial++;
        else if (c.status === "not-supported") notSupported++;
        else fail++;
      });
    });
  });
  return { pass, partial, fail, notSupported, total, rate: total ? Math.round(pass / total * 100) : 0 };
});

function capOf(req, libId, capKey) {
  return req.tests?.[libId]?.[capKey] || null;
}

function testsByLib(req) {
  const map = {};
  props.libs.forEach(lib => {
    const caps = req.tests?.[lib.id];
    if (!caps) return;
    const entries = [];
    Object.entries(caps).forEach(([capKey, cap]) => {
      cap.details?.forEach(d => entries.push({ ...d, capKey }));
    });
    if (entries.length) map[lib.id] = { lib, tests: entries };
  });
  return map;
}
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Hero -->
    <section class="relative mb-12">
      <div class="iso-watermark hidden md:block">
        <span style="top: 18%; left: 12%;">req:date-cal</span>
        <span style="top: 62%; right: 16%;">pass · partial · fail</span>
        <span style="top: 80%; left: 42%;">iso:8601:-1:ed-1</span>
      </div>
      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 00</span>
          <span class="clause-label">Cross-implementation comparison</span>
        </div>
        <h1 class="display-hero text-4xl md:text-6xl mb-4">
          Capability <em>matrix</em>.
        </h1>
        <p class="text-ink-soft text-base md:text-lg max-w-2xl leading-relaxed">
          Real stdlib behavior tested against {{ reqs.length }} ISO 8601 requirements across
          {{ libs.length }} versions — no hacks, no workarounds.
        </p>
      </div>
    </section>

    <!-- At a glance -->
    <section class="mb-10">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">At a glance</h2>
      </div>
      <div class="grid grid-cols-3 md:grid-cols-6 gap-px bg-rule">
        <div class="bg-surface p-4 text-center">
          <div class="stat-figure text-2xl text-ink">{{ reqs.length }}</div>
          <div class="clause-label mt-1">Requirements</div>
        </div>
        <div class="bg-surface p-4 text-center">
          <div class="stat-figure text-2xl text-ink">{{ libs.length }}</div>
          <div class="clause-label mt-1">Versions</div>
        </div>
        <div class="bg-surface p-4 text-center">
          <div class="stat-figure text-2xl text-jade">{{ totalStats.pass }}</div>
          <div class="clause-label mt-1">Passed</div>
        </div>
        <div class="bg-surface p-4 text-center">
          <div class="stat-figure text-2xl text-amber">{{ totalStats.partial }}</div>
          <div class="clause-label mt-1">Partial</div>
        </div>
        <div class="bg-surface p-4 text-center">
          <div class="stat-figure text-2xl text-rust">{{ totalStats.fail }}</div>
          <div class="clause-label mt-1">Failed</div>
        </div>
        <div class="bg-surface p-4 text-center">
          <div class="stat-figure text-2xl text-ink">{{ totalStats.rate }}%</div>
          <div class="clause-label mt-1">Pass Rate</div>
        </div>
      </div>
    </section>

    <!-- Toolbar -->
    <section class="mb-6">
      <div class="flex flex-wrap gap-2 mb-3 items-center">
        <div class="relative">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
          <input
            v-model="q"
            placeholder="Search requirements, sections…"
            class="surface w-64 pl-9 pr-3 py-2 font-mono text-sm text-ink placeholder-ink-faint outline-none focus:border-accent/50 transition-colors"
          />
        </div>

        <button
          v-for="c in categories"
          :key="c.name"
          @click="cat = cat === c.name ? null : c.name"
          :class="[
            'px-2.5 py-1.5 font-mono text-xs border transition-colors whitespace-nowrap',
            cat === c.name
              ? 'border-accent/50 text-accent surface-2'
              : 'surface border-rule text-ink-muted hover:border-accent/40 hover:text-ink'
          ]"
        >{{ c.name }} <span class="text-ink-faint">({{ c.count }})</span></button>
      </div>

      <div v-if="profiles.length" class="flex flex-wrap gap-1.5 items-center">
        <span class="clause-label mr-1">Profile</span>
        <button
          @click="profileFilter = null"
          :class="[
            'px-2 py-1 font-mono text-xs border transition-colors',
            !profileFilter ? 'border-accent/50 text-accent surface-2' : 'surface border-rule text-ink-faint hover:text-ink-muted'
          ]"
        >All</button>
        <button
          v-for="p in profiles"
          :key="p.id"
          @click="profileFilter = profileFilter === p.id ? null : p.id"
          :class="[
            'px-2 py-1 font-mono text-xs border transition-colors flex items-center gap-1.5',
            profileFilter === p.id ? 'border-accent/50 text-accent surface-2' : 'surface border-rule text-ink-faint hover:text-ink-muted'
          ]"
        >
          <img v-if="p.logo" :src="p.logo" class="w-3.5 h-3.5 opacity-80" />
          {{ p.name.replace('ISO 8601', '').trim() || p.name }}
        </button>
      </div>
    </section>

    <!-- Matrix table -->
    <section>
      <div class="surface overflow-x-auto">
        <table class="w-full border-collapse text-sm">
          <thead>
            <!-- Family header row -->
            <tr class="surface-2">
              <th class="text-left p-2.5 sticky left-0 z-10 surface-2 min-w-[280px] border-b border-rule">
                <span class="clause-label">Implementation</span>
              </th>
              <th
                v-for="group in families"
                :key="group.family"
                :colspan="group.versions.length * 3"
                :class="['text-center p-2.5 border-l border-rule border-b-2', pctBorderColor(familyStats[group.family]?.pct ?? 0)]"
              >
                <div class="flex items-center justify-center gap-2">
                  <img :src="group.logo" :alt="group.family" class="w-5 h-5" />
                  <span class="font-display text-sm text-ink">{{ group.family }}</span>
                  <span class="font-mono text-xs text-ink-faint">{{ group.versions.length }}v</span>
                  <span
                    class="font-mono text-xs tabular-nums"
                    :class="pctTextColor(familyStats[group.family]?.pct ?? 0)"
                    :title="`${familyStats[group.family]?.pass ?? 0} / ${familyStats[group.family]?.total ?? 0} capability checks passed across ${group.versions.length} versions`"
                  >{{ familyStats[group.family]?.pct ?? 0 }}%</span>
                </div>
              </th>
            </tr>
            <!-- Version header row -->
            <tr class="surface-2">
              <th class="p-2.5 text-left sticky left-0 z-10 surface-2 border-b border-rule">
                <span class="clause-label">Requirement</span>
              </th>
              <th
                v-for="lib in libs"
                :key="lib.id"
                colspan="3"
                :class="['text-center p-2 border-b border-rule', familyStartIds.has(lib.id) ? 'border-l border-rule' : '']"
              >
                <div class="font-mono text-sm text-ink">{{ libVersionLabel(lib) }}</div>
                <div class="font-mono text-[11px] text-ink-faint">{{ lib.language }}</div>
              </th>
            </tr>
            <!-- Sub-header row: Parse / Gen / Arith per version -->
            <tr class="surface-2">
              <th class="p-1 sticky left-0 z-10 surface-2 border-b border-rule"></th>
              <template v-for="lib in libs" :key="lib.id">
                <th :class="['p-1 font-mono text-[11px] text-ink-faint uppercase tracking-wider border-b border-rule', familyStartIds.has(lib.id) ? 'border-l border-rule' : '']">Parse</th>
                <th class="p-1 font-mono text-[11px] text-ink-faint uppercase tracking-wider border-b border-rule">Gen</th>
                <th class="p-1 font-mono text-[11px] text-ink-faint uppercase tracking-wider border-b border-rule">Arith</th>
              </template>
            </tr>
          </thead>
          <tbody>
            <template v-for="(reqsInCat, catName) in grouped" :key="catName">
              <tr class="surface-2">
                <td :colspan="1 + libs.length * 3" class="px-3 py-2 border-t border-b border-rule sticky left-0 z-[1] surface-2">
                  <span class="font-display text-sm text-ink">{{ catName }}</span>
                  <span class="clause-label ml-2 tabular-nums">{{ reqsInCat.length }} reqs</span>
                </td>
              </tr>
              <template v-for="r in reqsInCat" :key="r.id">
                <tr
                  class="border-b border-rule-soft hover:bg-surface-2/50 transition-colors cursor-pointer"
                  @click="toggleExpand(r.id)"
                >
                  <td class="p-2 sticky left-0 z-[1] bg-surface border-r border-rule min-w-[280px] max-w-[400px]">
                    <div class="flex items-center gap-1.5 flex-wrap">
                      <svg class="w-3.5 h-3.5 shrink-0 transition-transform text-ink-faint" :class="{ 'rotate-90': expanded.has(r.id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                      <span v-if="r.section" class="font-mono text-xs text-accent border border-accent/40 px-1.5 py-0.5 whitespace-nowrap">{{ r.section }}</span>
                      <span class="font-mono text-sm text-ink">{{ r.id.replace('req:', '') }}</span>
                      <span v-if="fmtTag(r.format)" class="micro-tag">{{ fmtTag(r.format) }}</span>
                      <span v-if="r.source_profile" class="pill pill-info">PROFILE</span>
                    </div>
                    <div v-if="r.statement" class="text-sm text-ink-muted mt-1 line-clamp-2 leading-snug">{{ trunc(r.statement, 120) }}</div>
                  </td>
                  <template v-for="lib in libs" :key="lib.id">
                    <td :class="['p-1 text-center min-w-[40px]', familyStartIds.has(lib.id) ? 'border-l border-rule' : 'border-l border-rule-soft']">
                      <CapabilityBadge :cap="capOf(r, lib.id, 'parse_general')" @click.stop="emit('open-detail', { rid: r.id, lid: lib.id, ctype: 'parse_general', c: capOf(r, lib.id, 'parse_general') })" />
                    </td>
                    <td class="p-1 text-center min-w-[40px] border-l border-rule-soft">
                      <CapabilityBadge :cap="capOf(r, lib.id, 'construct')" @click.stop="emit('open-detail', { rid: r.id, lid: lib.id, ctype: 'construct', c: capOf(r, lib.id, 'construct') })" />
                    </td>
                    <td class="p-1 text-center min-w-[40px] border-l border-rule-soft">
                      <CapabilityBadge :cap="capOf(r, lib.id, 'arithmetic')" @click.stop="emit('open-detail', { rid: r.id, lid: lib.id, ctype: 'arithmetic', c: capOf(r, lib.id, 'arithmetic') })" />
                    </td>
                  </template>
                </tr>
                <!-- Expanded detail row -->
                <tr v-if="expanded.has(r.id)" class="border-b border-rule-soft">
                  <td :colspan="1 + libs.length * 3" class="p-0">
                    <div class="surface-2 border-t border-b border-rule px-5 py-4">
                      <div class="mb-5">
                        <div class="flex items-center gap-2 mb-2 flex-wrap">
                          <span v-if="r.section" class="font-mono text-xs text-accent border border-accent/40 px-1.5 py-0.5">{{ r.section }}</span>
                          <span class="font-mono text-sm text-ink">{{ r.id.replace('req:', '') }}</span>
                          <span v-if="fmtTag(r.format)" class="micro-tag">{{ fmtTag(r.format) }}</span>
                        </div>
                        <p v-if="r.statement" class="font-display text-lg text-ink-soft leading-relaxed max-w-4xl">{{ r.statement }}</p>
                        <div v-if="r.pattern" class="mt-3 surface px-3 py-2 font-mono text-sm inline-flex items-center gap-2">
                          <span class="clause-label">Pattern</span>
                          <span class="text-steel">{{ r.pattern }}</span>
                        </div>
                      </div>

                      <div class="space-y-4">
                        <div v-for="({ lib, tests }, libId) in testsByLib(r)" :key="libId">
                          <div class="flex items-center gap-2 mb-2">
                            <img :src="lib.logo" :alt="lib.name" class="w-4 h-4" />
                            <span class="font-display text-sm text-ink">{{ lib.name }}</span>
                            <span class="font-mono text-xs text-ink-faint">{{ lib.version }}</span>
                          </div>
                          <div class="ml-6 space-y-1.5">
                            <div v-for="d in tests" :key="d.test_id + d.capKey" class="surface px-3 py-2">
                              <div class="flex items-center gap-2 flex-wrap mb-1.5">
                                <span :class="['pill', statusBg(d.result)]">
                                  <span>{{ statusIcon(d.result) }}</span>
                                </span>
                                <span class="font-mono text-xs text-ink">{{ d.test_id.replace('conf-test:', '') }}</span>
                                <span class="micro-tag">{{ capTypeLabel(d.capKey) }}</span>
                                <span class="text-sm text-ink-muted flex-1">{{ d.description }}</span>
                              </div>
                              <div v-if="(d.given && (d.given.expression || d.given.components || d.given.expression_a)) || d.actual" class="surface-2 p-2.5 font-mono text-xs space-y-1.5">
                                <div v-if="d.given?.expression">
                                  <span class="clause-label mr-1.5">Input</span>
                                  <span class="text-steel">{{ d.given.expression }}</span>
                                </div>
                                <div v-if="d.given?.expression_a">
                                  <span class="clause-label mr-1.5">Input</span>
                                  <span class="text-steel">{{ d.given.expression_a }} ≡ {{ d.given.expression_b }}</span>
                                </div>
                                <div v-if="d.expect?.expression">
                                  <span class="clause-label mr-1.5">Expected</span>
                                  <span class="text-jade">{{ d.expect.expression }}</span>
                                </div>
                                <div v-if="d.actual && d.result !== 'pass'">
                                  <span class="clause-label mr-1.5">Actual</span>
                                  <span class="text-ink-muted">{{ JSON.stringify(d.actual) }}</span>
                                </div>
                              </div>
                              <div v-if="d.api" class="font-mono text-xs text-ink-faint mt-1.5">API: {{ d.api }}</div>
                              <div v-if="d.notes" class="text-sm text-amber mt-1">{{ d.notes }}</div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </td>
                </tr>
              </template>
            </template>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>
