<script setup>
const props = defineProps({
  cap: { type: Object, default: null },
});

const ICONS = { pass: "✓", partial: "≈", fail: "✗", na: "—" };

function status(s) {
  return s || "na";
}
</script>

<template>
  <div class="inline-flex flex-col items-center">
    <button
      class="w-6 h-6 rounded flex items-center justify-center text-xs font-bold cursor-pointer hover:scale-125 transition-transform"
      :class="{
        'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400': status(cap?.status) === 'pass',
        'bg-amber-500/10 text-amber-600 dark:text-amber-400': status(cap?.status) === 'partial',
        'bg-red-500/8 text-red-500 dark:text-red-400': status(cap?.status) === 'fail',
        'bg-gray-700/30 text-gray-600 text-[10px]': !cap,
      }"
    >{{ ICONS[status(cap?.status)] }}</button>
    <div v-if="cap" class="text-[9px] text-gray-600 mt-px tabular-nums">{{ cap.pass }}/{{ cap.total }}</div>
  </div>
</template>
