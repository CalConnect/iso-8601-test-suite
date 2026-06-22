<script setup>
import { statusColor, statusBg, statusIcon } from "../composables/useStatus";
import { typeLabel, trunc, formatValue } from "../composables/useFormat";

const props = defineProps({
  detail: { type: Object, required: true },
  libs: { type: Array, required: true },
});

const emit = defineEmits(["close"]);
</script>

<template>
  <div class="fixed inset-0 z-[100] flex items-center justify-center bg-ink/40 backdrop-blur-sm" @click.self="emit('close')">
    <div class="bg-paper border border-rule w-[94%] max-w-[620px] max-h-[85vh] overflow-y-auto shadow-2xl">
      <div class="sticky top-0 bg-surface px-5 py-3 border-b border-rule flex justify-between items-start z-10">
        <div class="flex items-center gap-3 min-w-0">
          <span class="font-mono text-xs text-accent">{{ detail.rid.replace('req:', '') }}</span>
          <span class="clause-label">{{ detail.lid }}</span>
        </div>
        <button @click="emit('close')"
          class="w-7 h-7 border border-rule text-ink-faint hover:text-ink hover:border-accent/50 flex items-center justify-center text-base transition-colors">&times;</button>
      </div>
      <div class="px-5 py-4">
        <div class="flex flex-wrap gap-4 mb-4">
          <span class="clause-label">Type: <strong class="text-ink-muted">{{ typeLabel(detail.ctype) }}</strong></span>
          <span v-if="detail.c" class="clause-label">Result: <strong class="text-ink-muted tabular-nums">{{ detail.c.pass }}/{{ detail.c.total }}</strong></span>
        </div>

        <p v-if="!detail.c?.details?.length" class="clause-label py-6 text-center">No tests for this capability.</p>

        <div v-else class="border-t border-rule">
          <div v-for="d in detail.c.details" :key="d.test_id" class="py-3 border-b border-rule-soft last:border-0">
            <div class="flex items-center gap-2 mb-1 flex-wrap">
              <span class="font-mono text-xs text-ink">{{ d.test_id.replace('conf-test:', '') }}</span>
              <span :class="['pill', statusBg(d.result)]">
                <span>{{ statusIcon(d.result) }}</span>
                <span>{{ d.result }}</span>
              </span>
            </div>
            <div v-if="d.description" class="text-sm text-ink-muted">{{ d.description }}</div>

            <div v-if="d.given?.expression || d.given?.components || d.given?.expression_a || d.actual" class="mt-2 surface-2 p-3 font-mono text-xs space-y-2">
              <div v-if="d.given?.expression">
                <div class="clause-label mb-0.5">Input</div>
                <div class="text-steel">{{ d.given.expression }}</div>
              </div>
              <div v-if="d.given?.expression_a">
                <div class="clause-label mb-0.5">Input</div>
                <div class="text-steel">{{ d.given.expression_a }} ≡ {{ d.given.expression_b }}</div>
              </div>
              <div v-if="d.given?.components">
                <div class="clause-label mb-0.5">Components</div>
                <pre class="text-steel/80 text-[11px] whitespace-pre-wrap">{{ JSON.stringify(d.given.components, null, 2) }}</pre>
              </div>
              <div v-if="d.expect?.expression">
                <div class="clause-label mb-0.5">Expected</div>
                <div class="text-jade">{{ d.expect.expression }}</div>
              </div>
              <div v-if="d.expect?.valid !== undefined && !d.expect?.expression">
                <div class="clause-label mb-0.5">Expected</div>
                <pre class="text-jade/80 text-[11px] whitespace-pre-wrap">{{ JSON.stringify(d.expect, null, 2) }}</pre>
              </div>
              <div v-if="d.actual">
                <div class="clause-label mb-0.5">Actual</div>
                <pre class="text-ink-muted text-[11px] whitespace-pre-wrap">{{ JSON.stringify(d.actual, null, 2) }}</pre>
              </div>
            </div>

            <div v-if="d.api" class="font-mono text-xs text-ink-faint mt-2">{{ d.api }}</div>
            <div v-if="d.notes" class="text-sm text-amber mt-1">{{ d.notes }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
