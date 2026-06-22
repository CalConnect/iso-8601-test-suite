import { computed, onMounted, onUnmounted, ref } from "vue";

const STATIC_PHRASES = [
  "There is one timezone: UTC. The rest are costumes.",
  "Calendar math is hard. That's why we wrote the tests.",
  "1985-04-12T23:20:30Z — the canonical anchor.",
  "P3Y6M4DT12H30M5S — duration, decomposed.",
  "Conform or be parsed.",
  "Date parsing should not be vibes-based.",
  "Every library has an opinion. Few are correct.",
  "Extended or basic. Never both.",
  "2026-W15-3 — week dates, finally unambiguous.",
  "Midnight is 00:00, not 24:00. Always has been.",
  "Reduced precision: not a bug, a feature.",
  "Time is the only honest currency.",
  "Where standards meet reality.",
  "T is not optional. Z is not decorative.",
  "Timezones are political. Timestamps are not.",
  "Year, month, day. In that order. Always.",
];

export function useMOTD(ctx = {}) {
  const index = ref(Math.floor(Math.random() * STATIC_PHRASES.length));

  const dataAware = computed(() => {
    const out = [];
    const r = ctx.reqs?.value;
    const l = ctx.libs?.value;
    const p = ctx.profiles?.value;
    const t = ctx.tests?.value;
    const best = ctx.bestPct?.value;
    const mean = ctx.meanPct?.value;
    const fams = ctx.familyCount?.value;
    if (r && l) out.push(`${r} requirements · ${l} implementations · 1 standard.`);
    if (p) out.push(`${p} profiles registered with the suite.`);
    if (t) out.push(`${t} conformance tests, executed.`);
    if (fams) out.push(`${fams} implementation families under test.`);
    if (Number.isFinite(mean)) out.push(`Mean conformance: ${mean}%. Standard library reality.`);
    if (Number.isFinite(best)) out.push(`Best score: ${best}%. Worst truth: library gaps.`);
    return out;
  });

  const all = computed(() => [...dataAware.value, ...STATIC_PHRASES]);
  const current = computed(() => {
    const arr = all.value;
    return arr.length ? arr[index.value % arr.length] : "";
  });

  let tickTimer = null;

  onMounted(() => {
    tickTimer = setInterval(() => {
      const len = all.value.length || 1;
      index.value = (index.value + 1) % len;
    }, 7000);
  });

  onUnmounted(() => {
    if (tickTimer) clearInterval(tickTimer);
  });

  return { current };
}
