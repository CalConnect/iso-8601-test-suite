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

function pctColor(pct) {
  return pct >= 40 ? "emerald" : pct >= 15 ? "amber" : "red";
}

function reqCount(p) {
  return p.traceability_class_count || p.traceability?.length || 0;
}

function testCount(p) {
  return p.traceability?.reduce((sum, cc) => sum + cc.requirements.reduce((s, r) => s + r.tests.length, 0), 0) || 0;
}
</script>

<template>
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-8">
    <div class="text-center pb-8 mb-8 border-b border-gray-800/60">
      <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight mb-2">
        ISO 8601 <span class="text-[#e3000f]">Profiles</span>
      </h1>
      <p class="text-gray-500 text-sm max-w-lg mx-auto leading-relaxed">
        {{ profiles.length }} profiles defined under ISO 8601, each representing a specific subset of requirements for targeted use cases.
      </p>

      <!-- Profile selection guidance -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mt-6 max-w-3xl mx-auto">
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-4 text-left">
          <div class="text-xs font-bold text-gray-300 mb-2">Web &amp; Internet</div>
          <div class="text-[10px] text-gray-500 leading-relaxed">
            <button @click="emit('navigate', '/profile/rfc-3339')" class="text-blue-400 hover:text-blue-300 transition-colors">RFC 3339</button> — APIs, protocols<br>
            <button @click="emit('navigate', '/profile/w3c-datetime')" class="text-blue-400 hover:text-blue-300 transition-colors">W3C Datetime</button> — HTML metadata
          </div>
        </div>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-4 text-left">
          <div class="text-xs font-bold text-gray-300 mb-2">Libraries &amp; Archives</div>
          <div class="text-[10px] text-gray-500 leading-relaxed">
            <button @click="emit('navigate', '/profile/edtf-level-0')" class="text-blue-400 hover:text-blue-300 transition-colors">EDTF 0</button> — basic extended dates<br>
            <button @click="emit('navigate', '/profile/edtf-level-1')" class="text-blue-400 hover:text-blue-300 transition-colors">EDTF 1</button> — uncertain/approximate<br>
            <button @click="emit('navigate', '/profile/edtf-level-2')" class="text-blue-400 hover:text-blue-300 transition-colors">EDTF 2</button> — structured expressions
          </div>
        </div>
        <div class="bg-gray-900/50 border border-gray-800/60 rounded-lg p-4 text-left">
          <div class="text-xs font-bold text-gray-300 mb-2">Full Compliance</div>
          <div class="text-[10px] text-gray-500 leading-relaxed">
            <button @click="emit('navigate', '/profile/iso-8601-1-basic-format')" class="text-blue-400 hover:text-blue-300 transition-colors">Basic Format</button> — compact storage<br>
            <button @click="emit('navigate', '/profile/iso-8601-1-complete')" class="text-blue-400 hover:text-blue-300 transition-colors">ISO 8601-1</button> — full Part 1<br>
            <button @click="emit('navigate', '/profile/iso-8601-2-complete')" class="text-blue-400 hover:text-blue-300 transition-colors">ISO 8601-2</button> — full Part 1 + 2
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div
        v-for="p in sortedProfiles"
        :key="p.id"
        class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-6 hover:border-gray-700 transition-colors cursor-pointer group"
        @click="emit('navigate', '/profile/' + p.id.replace('profile:', ''))"
      >
        <div class="flex items-start justify-between mb-3">
          <div class="flex items-center gap-3">
            <img v-if="p.logo" :src="p.logo" :alt="p.name" class="h-6 w-auto opacity-80" />
            <div>
              <div class="font-bold text-base group-hover:text-gray-100 transition-colors">{{ p.name }}</div>
              <div class="font-mono text-[11px] text-gray-500">{{ p.id }}</div>
            </div>
          </div>
          <div class="text-right">
            <div class="text-lg font-extrabold tabular-nums" :class="{
              'text-emerald-600 dark:text-emerald-400': pctColor(profilePct(p)) === 'emerald',
              'text-amber-600 dark:text-amber-400': pctColor(profilePct(p)) === 'amber',
              'text-red-500 dark:text-red-400': pctColor(profilePct(p)) === 'red',
            }">{{ profilePct(p) }}%</div>
            <div class="text-[9px] text-gray-500 uppercase tracking-wider">best lib</div>
          </div>
        </div>

        <p v-if="p.description" class="text-xs text-gray-500 mb-4 leading-relaxed">{{ trunc(p.description, 250) }}</p>

        <div class="flex gap-4 text-[10px] text-gray-600 mb-4">
          <span>{{ reqCount(p) }} traceability classes</span>
          <span>{{ testCount(p) }} test cases</span>
          <span>{{ (p.additional_requirements || []).length }} add'l reqs</span>
        </div>

        <div class="space-y-2">
          <div v-for="ar in p.adapter_results" :key="ar.id" class="flex items-center gap-3">
            <span class="w-28 text-[11px] font-semibold text-gray-400 truncate shrink-0">
              {{ libs.find(l => l.id === ar.id)?.name?.split(' ').slice(0, 2).join(' ') || ar.id }}
            </span>
            <div class="flex-1 h-1.5 bg-gray-800 rounded-full overflow-hidden">
              <div
                class="h-full rounded-full transition-all duration-400"
                :class="{
                  'bg-emerald-500': pctColor(ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0) === 'emerald',
                  'bg-amber-500': pctColor(ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0) === 'amber',
                  'bg-red-500': pctColor(ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0) === 'red',
                }"
                :style="{ width: (ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0) + '%' }"
              ></div>
            </div>
            <span
              class="text-[11px] tabular-nums w-10 text-right shrink-0"
              :class="{
                'text-emerald-600 dark:text-emerald-400': pctColor(ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0) === 'emerald',
                'text-amber-600 dark:text-amber-400': pctColor(ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0) === 'amber',
                'text-red-500 dark:text-red-400': pctColor(ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0) === 'red',
              }"
            >{{ ar.test_total ? Math.round(ar.test_pass / ar.test_total * 100) : 0 }}%</span>
          </div>
        </div>

        <div class="mt-4 text-[10px] text-gray-600 group-hover:text-gray-400 transition-colors flex items-center gap-1">
          View full traceability
          <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
        </div>
      </div>
    </div>
  </div>
</template>
