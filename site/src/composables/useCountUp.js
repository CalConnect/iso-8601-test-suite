import { onMounted, ref, watch } from "vue";

function easeOutCubic(t) {
  return 1 - Math.pow(1 - t, 3);
}

export function useCountUp(target, { duration = 1200, disabled = false } = {}) {
  const display = ref(0);
  let raf = null;
  let startedAt = 0;

  function run(to) {
    if (disabled || !Number.isFinite(to) || to === 0) {
      display.value = to;
      return;
    }
    cancelAnimationFrame(raf);
    startedAt = 0;
    const from = 0;
    const delta = to - from;
    const step = (ts) => {
      if (!startedAt) startedAt = ts;
      const elapsed = ts - startedAt;
      const t = Math.min(1, elapsed / duration);
      display.value = Math.round(from + delta * easeOutCubic(t));
      if (t < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
  }

  onMounted(() => run(target?.value ?? target));
  watch(() => target?.value ?? target, (v) => run(v));

  return display;
}
