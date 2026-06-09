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
  <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-8">
    <div class="text-center pb-8 mb-8 border-b border-gray-800/60">
      <h1 class="text-2xl md:text-3xl font-extrabold tracking-tight mb-2">
        Test <span class="text-[#e3000f]">Reports</span>
      </h1>
      <p class="text-gray-500 text-sm max-w-lg mx-auto leading-relaxed">
        Download full YAML conformance test results per library.
      </p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div
        v-for="lib in libs"
        :key="lib.id"
        class="bg-gray-900/50 border border-gray-800/60 rounded-xl p-6 text-center hover:border-gray-700 transition-colors"
      >
        <div class="flex items-center justify-center gap-3 mb-4">
          <img :src="lib.logo" :alt="lib.name" class="w-10 h-10 rounded-lg" />
          <div class="text-left">
            <div class="font-bold text-sm">{{ lib.name }}</div>
            <div class="text-[10px] text-gray-500">{{ lib.language }} {{ lib.version }}</div>
          </div>
        </div>

        <div class="flex justify-center gap-5 mb-5">
          <div class="text-center">
            <div class="text-xl font-extrabold tabular-nums text-emerald-600 dark:text-emerald-400">{{ libStats(lib, reqs).pass }}</div>
            <div class="text-[10px] text-gray-500 uppercase tracking-wider">Passed</div>
          </div>
          <div class="text-center">
            <div class="text-xl font-extrabold tabular-nums text-amber-600 dark:text-amber-400">{{ libStats(lib, reqs).partial }}</div>
            <div class="text-[10px] text-gray-500 uppercase tracking-wider">Partial</div>
          </div>
          <div class="text-center">
            <div class="text-xl font-extrabold tabular-nums text-red-500 dark:text-red-400">{{ libStats(lib, reqs).fail }}</div>
            <div class="text-[10px] text-gray-500 uppercase tracking-wider">Failed</div>
          </div>
          <div class="text-center">
            <div class="text-xl font-extrabold tabular-nums text-gray-400">{{ libStats(lib, reqs).total }}</div>
            <div class="text-[10px] text-gray-500 uppercase tracking-wider">Total</div>
          </div>
        </div>

        <a
          :href="'/results/' + lib.id + '.yaml'"
          download
          class="inline-block px-4 py-1.5 bg-gray-800/50 border border-gray-700/50 rounded-md text-xs text-gray-400 hover:bg-[#e3000f]/10 hover:border-[#e3000f]/30 hover:text-gray-100 transition-colors no-underline"
        >Download YAML</a>
      </div>
    </div>
  </div>
</template>
