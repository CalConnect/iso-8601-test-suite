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
      class="w-6 h-6 flex items-center justify-center text-xs font-bold cursor-pointer hover:scale-125 transition-transform"
      :class="{
        'text-jade': status(cap?.status) === 'pass',
        'text-amber': status(cap?.status) === 'partial',
        'text-rust': status(cap?.status) === 'fail',
        'text-ink-faint text-[10px]': !cap,
      }"
    >{{ ICONS[status(cap?.status)] }}</button>
    <div v-if="cap" class="font-mono text-[10px] text-ink-faint mt-px tabular-nums">{{ cap.pass }}/{{ cap.total }}</div>
  </div>
</template>
