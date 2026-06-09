<script setup>
import { statusColor } from "../composables/useStatus";
import { typeLabel, trunc, formatValue } from "../composables/useFormat";

const props = defineProps({
  detail: { type: Object, required: true },
  libs: { type: Array, required: true },
});

const emit = defineEmits(["close"]);
</script>

<template>
  <div class="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 backdrop-blur-sm" @click.self="emit('close')">
    <div class="bg-gray-900 border border-gray-800 rounded-xl w-[94%] max-w-[620px] max-h-[85vh] overflow-y-auto shadow-2xl">
      <div class="sticky top-0 bg-gray-800 px-5 py-3 border-b border-gray-700 flex justify-between items-start z-10">
        <h3 class="font-mono text-sm text-blue-600 dark:text-blue-400 font-semibold">{{ detail.rid.replace('req:', '') }}</h3>
        <button @click="emit('close')" class="w-7 h-7 rounded-md border border-gray-700 text-gray-500 hover:text-gray-200 hover:border-gray-500 flex items-center justify-center text-base transition-colors">&times;</button>
      </div>
      <div class="px-5 py-4">
        <div class="flex flex-wrap gap-4 text-xs text-gray-500 mb-4">
          <span>Library: <strong class="text-gray-400">{{ detail.lid }}</strong></span>
          <span>Type: <strong class="text-gray-400">{{ typeLabel(detail.ctype) }}</strong></span>
          <span v-if="detail.c">Result: <strong class="text-gray-400">{{ detail.c.pass }}/{{ detail.c.total }}</strong></span>
        </div>

        <p v-if="!detail.c?.details?.length" class="text-gray-500 text-sm">No tests for this capability.</p>

        <div v-else class="border-t border-gray-800">
          <div v-for="d in detail.c.details" :key="d.test_id" class="py-3 border-b border-gray-800/50 last:border-0">
            <div class="flex items-center gap-2 mb-1">
              <span class="font-mono text-[11px] text-gray-500">{{ d.test_id.replace('conf-test:', '') }}</span>
              <span class="text-[10px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded" :class="{
                'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400': d.result === 'pass',
                'bg-red-500/10 text-red-500 dark:text-red-400': d.result === 'fail',
                'bg-gray-700/30 text-gray-500': d.result === 'not-supported',
              }">{{ d.result }}</span>
            </div>
            <div v-if="d.description" class="text-xs text-gray-500">{{ d.description }}</div>

            <div v-if="d.given?.expression || d.given?.components || d.given?.expression_a || d.actual" class="mt-2 bg-gray-950 border border-gray-800 rounded-md p-3 font-mono text-xs">
              <div v-if="d.given?.expression">
                <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-1">Input</div>
                <div class="text-blue-600 dark:text-blue-300">{{ d.given.expression }}</div>
              </div>
              <div v-if="d.given?.expression_a">
                <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-1">Input</div>
                <div class="text-blue-600 dark:text-blue-300">{{ d.given.expression_a }} ≡ {{ d.given.expression_b }}</div>
              </div>
              <div v-if="d.given?.components">
                <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-1">Components</div>
                <pre class="text-blue-600/80 dark:text-blue-300/80 text-[10px] whitespace-pre-wrap">{{ JSON.stringify(d.given.components, null, 2) }}</pre>
              </div>
              <div v-if="d.expect?.expression" class="mt-2">
                <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-1">Expected</div>
                <div class="text-emerald-600 dark:text-emerald-400">{{ d.expect.expression }}</div>
              </div>
              <div v-if="d.expect?.valid !== undefined && !d.expect?.expression" class="mt-2">
                <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-1">Expected</div>
                <pre class="text-emerald-600/80 dark:text-emerald-400/80 text-[10px] whitespace-pre-wrap">{{ JSON.stringify(d.expect, null, 2) }}</pre>
              </div>
              <div v-if="d.actual" class="mt-2">
                <div class="text-[9px] uppercase tracking-wider text-gray-500 font-bold mb-1">Actual</div>
                <pre class="text-gray-400 text-[10px] whitespace-pre-wrap">{{ JSON.stringify(d.actual, null, 2) }}</pre>
              </div>
            </div>

            <div v-if="d.api" class="font-mono text-[10px] text-gray-600 mt-1">{{ d.api }}</div>
            <div v-if="d.notes" class="text-[11px] text-amber-600/80 dark:text-amber-500/80 mt-1">{{ d.notes }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
