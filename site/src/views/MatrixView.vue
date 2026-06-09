<script setup>
import { ref, computed } from "vue";
import CapabilityBadge from "../components/CapabilityBadge.vue";
import { statusColor, statusBg, statusIcon } from "../composables/useStatus";
import { fmtTag, capTypeLabel, trunc, libShortName } from "../composables/useFormat";

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
  let pass = 0, partial = 0, fail = 0, total = 0;
  props.reqs.forEach(r => {
    props.libs.forEach(l => {
      const caps = r.tests?.[l.id];
      if (!caps) return;
      Object.values(caps).forEach(c => {
        total++;
        if (c.status === "pass") pass++;
        else if (c.status === "partial") partial++;
        else fail++;
      });
    });
  });
  return { pass, partial, fail, total, rate: total ? Math.round(pass / total * 100) : 0 };
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
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-8">
    <!-- Hero -->
    <div class="text-center pb-8 mb-8 border-b border-gray-800/60">
      <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight mb-2">
        Capability <span class="text-[#e3000f]">Matrix</span>
      </h1>
      <p class="text-gray-500 text-sm max-w-lg mx-auto leading-relaxed">
        Real stdlib behavior tested against {{ reqs.length }} ISO 8601 requirements — no hacks, no workarounds.
      </p>
      <div class="grid grid-cols-3 md:grid-cols-6 gap-2 max-w-xl mx-auto mt-5">
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-2.5 text-center">
          <div class="text-xl font-extrabold tabular-nums">{{ reqs.length }}</div>
          <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">Requirements</div>
        </div>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-2.5 text-center">
          <div class="text-xl font-extrabold tabular-nums text-gray-100">{{ libs.length }}</div>
          <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">Libraries</div>
        </div>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-2.5 text-center">
          <div class="text-xl font-extrabold tabular-nums text-emerald-600 dark:text-emerald-400">{{ totalStats.pass }}</div>
          <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">Passed</div>
        </div>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-2.5 text-center">
          <div class="text-xl font-extrabold tabular-nums text-amber-600 dark:text-amber-400">{{ totalStats.partial }}</div>
          <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">Partial</div>
        </div>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-2.5 text-center">
          <div class="text-xl font-extrabold tabular-nums text-red-500 dark:text-red-400">{{ totalStats.fail }}</div>
          <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">Failed</div>
        </div>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-2.5 text-center">
          <div class="text-xl font-extrabold tabular-nums">{{ totalStats.rate }}%</div>
          <div class="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">Pass Rate</div>
        </div>
      </div>
    </div>

    <!-- Toolbar -->
    <div class="flex flex-wrap gap-2 mb-4 items-center">
      <div class="relative">
        <svg class="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-500" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input
          v-model="q"
          placeholder="Search requirements, sections…"
          class="bg-gray-900/50 border border-gray-800/60 rounded-md text-sm pl-8 pr-3 py-1.5 w-60 outline-none focus:border-[#e3000f]/50 transition-colors text-gray-100 placeholder-gray-600"
        />
      </div>

      <!-- Category filters -->
      <button
        @click="cat = null"
        :class="[
          'px-2.5 py-1.5 rounded-md text-xs font-medium border transition-colors',
          !cat ? 'bg-[#e3000f]/10 text-[#e3000f] border-[#e3000f]/30' : 'bg-gray-900/50 text-gray-500 border-gray-800/60 hover:border-gray-700 hover:text-gray-300'
        ]"
      >All</button>
      <button
        v-for="c in categories"
        :key="c.name"
        @click="cat = cat === c.name ? null : c.name"
        :class="[
          'px-2.5 py-1.5 rounded-md text-xs font-medium border transition-colors whitespace-nowrap',
          cat === c.name ? 'bg-[#e3000f]/10 text-[#e3000f] border-[#e3000f]/30' : 'bg-gray-900/50 text-gray-500 border-gray-800/60 hover:border-gray-700 hover:text-gray-300'
        ]"
      >{{ c.name }} <span class="opacity-50">({{ c.count }})</span></button>
    </div>

    <!-- Profile filter -->
    <div v-if="profiles.length" class="flex flex-wrap gap-1.5 mb-4">
      <span class="text-[10px] text-gray-600 uppercase tracking-wider font-bold self-center mr-1">Profile:</span>
      <button
        @click="profileFilter = null"
        :class="[
          'px-2 py-1 rounded text-[10px] font-medium border transition-colors',
          !profileFilter ? 'bg-blue-500/10 text-blue-400 border-blue-500/30' : 'bg-gray-900/50 text-gray-600 border-gray-800/60 hover:border-gray-700 hover:text-gray-400'
        ]"
      >All</button>
      <button
        v-for="p in profiles"
        :key="p.id"
        @click="profileFilter = profileFilter === p.id ? null : p.id"
        :class="[
          'px-2 py-1 rounded text-[10px] font-medium border transition-colors flex items-center gap-1',
          profileFilter === p.id ? 'bg-blue-500/10 text-blue-400 border-blue-500/30' : 'bg-gray-900/50 text-gray-600 border-gray-800/60 hover:border-gray-700 hover:text-gray-400'
        ]"
      >
        <img v-if="p.logo" :src="p.logo" class="w-3 h-3 rounded opacity-70" />
        {{ p.name.replace('ISO 8601', '').trim() || p.name }}
      </button>
    </div>

    <!-- Matrix table -->
    <div class="overflow-x-auto border border-gray-800/60 rounded-xl bg-gray-900/50">
      <table class="w-full border-collapse text-xs">
        <thead>
          <tr class="bg-gray-800/60">
            <th class="text-left p-2 font-semibold text-gray-400 sticky left-0 z-10 bg-gray-800/60 min-w-[280px]">Requirement</th>
            <th
              v-for="lib in libs"
              :key="lib.id"
              colspan="3"
              class="text-center p-2 font-semibold border-l border-gray-700/50"
            >
              <div class="flex items-center justify-center gap-1.5">
                <img :src="lib.logo" :alt="lib.name" class="w-5 h-5 rounded" />
                <span class="text-gray-100 font-bold text-[11px]">{{ libShortName(lib.name) }}</span>
              </div>
              <div class="text-[10px] text-gray-500 font-normal">{{ lib.version }}</div>
            </th>
          </tr>
          <tr class="bg-gray-800/40">
            <th class="p-1"></th>
            <template v-for="lib in libs" :key="lib.id">
              <th class="p-1 text-[9px] text-gray-500 uppercase tracking-wider font-medium border-l border-gray-700/30">Parse</th>
              <th class="p-1 text-[9px] text-gray-500 uppercase tracking-wider font-medium">Gen</th>
              <th class="p-1 text-[9px] text-gray-500 uppercase tracking-wider font-medium">Arith</th>
            </template>
          </tr>
        </thead>
        <tbody>
          <template v-for="(reqsInCat, catName) in grouped" :key="catName">
            <tr class="bg-gray-800/30">
              <td :colspan="1 + libs.length * 3" class="px-3 py-2 font-bold text-gray-400 text-xs border-t border-b border-gray-700/50 sticky left-0 z-[1] bg-gray-800/30">
                {{ catName }}
                <span class="font-normal text-gray-600 text-[11px] ml-2">{{ reqsInCat.length }} reqs</span>
              </td>
            </tr>
            <template v-for="r in reqsInCat" :key="r.id">
              <tr
                class="border-b border-gray-800/30 hover:bg-gray-100/[0.02] transition-colors cursor-pointer"
                @click="toggleExpand(r.id)"
              >
                <td class="p-2 sticky left-0 z-[1] bg-gray-950 border-r border-gray-800/50 min-w-[280px] max-w-[400px]">
                  <div class="flex items-center gap-1.5 flex-wrap">
                    <svg class="w-3 h-3 shrink-0 transition-transform text-gray-600" :class="{ 'rotate-90': expanded.has(r.id) }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
                    <span v-if="r.section" class="font-mono text-[10px] font-bold text-[#e3000f] bg-[#e3000f]/10 px-1.5 py-0.5 rounded whitespace-nowrap">{{ r.section }}</span>
                    <span class="font-mono text-[11px] text-gray-500">{{ r.id.replace('req:', '') }}</span>
                    <span v-if="fmtTag(r.format)" class="text-[9px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-500 uppercase font-semibold tracking-wider">{{ fmtTag(r.format) }}</span>
                    <span v-if="r.source_profile" class="text-[8px] px-1 py-0.5 rounded bg-blue-500/10 text-blue-400 border border-blue-500/20 font-bold">PROFILE</span>
                  </div>
                  <div v-if="r.statement" class="text-[11px] text-gray-500 mt-0.5 line-clamp-2 leading-snug">{{ trunc(r.statement, 120) }}</div>
                </td>
                <template v-for="lib in libs" :key="lib.id">
                  <td class="p-1 text-center border-l border-gray-800/20 min-w-[40px]">
                    <CapabilityBadge :cap="capOf(r, lib.id, 'parse_general')" @click.stop="emit('open-detail', { rid: r.id, lid: lib.id, ctype: 'parse_general', c: capOf(r, lib.id, 'parse_general') })" />
                  </td>
                  <td class="p-1 text-center min-w-[40px]">
                    <CapabilityBadge :cap="capOf(r, lib.id, 'construct')" @click.stop="emit('open-detail', { rid: r.id, lid: lib.id, ctype: 'construct', c: capOf(r, lib.id, 'construct') })" />
                  </td>
                  <td class="p-1 text-center min-w-[40px]">
                    <CapabilityBadge :cap="capOf(r, lib.id, 'arithmetic')" @click.stop="emit('open-detail', { rid: r.id, lid: lib.id, ctype: 'arithmetic', c: capOf(r, lib.id, 'arithmetic') })" />
                  </td>
                </template>
              </tr>
              <!-- Expanded detail row -->
              <tr v-if="expanded.has(r.id)" class="border-b border-gray-800/30">
                <td :colspan="1 + libs.length * 3" class="p-0">
                  <div class="bg-gray-950/80 border-t border-b border-gray-700/30 px-5 py-4">
                    <div class="mb-4">
                      <div class="flex items-center gap-2 mb-2">
                        <span v-if="r.section" class="font-mono text-[10px] font-bold text-[#e3000f] bg-[#e3000f]/10 px-1.5 py-0.5 rounded">{{ r.section }}</span>
                        <span class="font-mono text-xs text-gray-500 font-semibold">{{ r.id.replace('req:', '') }}</span>
                        <span v-if="fmtTag(r.format)" class="text-[9px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-500 uppercase font-semibold tracking-wider">{{ fmtTag(r.format) }}</span>
                      </div>
                      <p v-if="r.statement" class="text-sm text-gray-300 leading-relaxed max-w-4xl">{{ r.statement }}</p>
                      <div v-if="r.pattern" class="mt-2 bg-gray-950 border border-gray-800/50 rounded-md px-3 py-2 font-mono text-[11px] inline-block">
                        <span class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mr-2">Pattern</span>
                        <span class="text-blue-600 dark:text-blue-300">{{ r.pattern }}</span>
                      </div>
                    </div>

                    <div class="space-y-4">
                      <div v-for="({ lib, tests }, libId) in testsByLib(r)" :key="libId">
                        <div class="flex items-center gap-2 mb-2">
                          <img :src="lib.logo" :alt="lib.name" class="w-4 h-4 rounded" />
                          <span class="text-[11px] font-bold text-gray-300">{{ lib.name }}</span>
                          <span class="text-[10px] text-gray-600">{{ lib.version }}</span>
                        </div>
                        <div class="ml-6 space-y-1.5">
                          <div v-for="d in tests" :key="d.test_id + d.capKey" class="bg-gray-900/50 border border-gray-800/40 rounded-lg px-3 py-2">
                            <div class="flex items-center gap-2 flex-wrap mb-1">
                              <span class="text-[9px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded border" :class="statusBg(d.result)">
                                <span :class="statusColor(d.result)">{{ statusIcon(d.result) }}</span>
                              </span>
                              <span class="font-mono text-[10px] text-gray-500">{{ d.test_id.replace('conf-test:', '') }}</span>
                              <span class="text-[9px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-500 uppercase font-semibold tracking-wider">{{ capTypeLabel(d.capKey) }}</span>
                              <span class="text-[10px] text-gray-500">{{ d.description }}</span>
                            </div>
                            <div v-if="(d.given && (d.given.expression || d.given.components || d.given.expression_a)) || d.actual" class="mt-1.5 bg-gray-950 rounded-md p-2.5 font-mono text-[11px] space-y-1.5 border border-gray-800/30">
                              <div v-if="d.given?.expression">
                                <span class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mr-1.5">Input</span>
                                <span class="text-blue-600 dark:text-blue-300">{{ d.given.expression }}</span>
                              </div>
                              <div v-if="d.given?.expression_a">
                                <span class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mr-1.5">Input</span>
                                <span class="text-blue-600 dark:text-blue-300">{{ d.given.expression_a }} ≡ {{ d.given.expression_b }}</span>
                              </div>
                              <div v-if="d.expect?.expression">
                                <span class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mr-1.5">Expected</span>
                                <span class="text-emerald-600 dark:text-emerald-400">{{ d.expect.expression }}</span>
                              </div>
                              <div v-if="d.actual && d.result !== 'pass'">
                                <span class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mr-1.5">Actual</span>
                                <span class="text-gray-400">{{ JSON.stringify(d.actual) }}</span>
                              </div>
                            </div>
                            <div v-if="d.api" class="font-mono text-[10px] text-gray-600 mt-1">API: {{ d.api }}</div>
                            <div v-if="d.notes" class="text-[10px] text-amber-600/80 dark:text-amber-500/80 mt-1">{{ d.notes }}</div>
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
  </div>
</template>
