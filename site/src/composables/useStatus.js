// Shared status styling functions — single source of truth for pass/partial/fail/not-supported visuals.

export function statusColor(s) {
  if (s === "pass") return "text-jade";
  if (s === "partial") return "text-amber";
  if (s === "fail") return "text-rust";
  if (s === "not-supported") return "text-ink-faint";
  return "text-ink-muted";
}

export function statusBg(s) {
  if (s === "pass") return "text-jade border-current/40";
  if (s === "partial") return "text-amber border-current/40";
  if (s === "fail") return "text-rust border-current/40";
  if (s === "not-supported") return "text-ink-faint border-rule";
  return "text-ink-muted border-rule";
}

export function statusIcon(s) {
  if (s === "pass") return "✓";
  if (s === "partial") return "≈";
  if (s === "fail") return "✗";
  if (s === "not-supported") return "—";
  return "—";
}

export function statusLabel(s) {
  if (s === "pass") return "Passed";
  if (s === "partial") return "Partial";
  if (s === "fail") return "Failed";
  if (s === "not-supported") return "Not supported";
  return "Unknown";
}

export function detClass(d) {
  if (d === "full") return "pill-pass";
  if (d === "partial") return "pill-partial";
  return "pill-muted";
}

export function detLabel(d) {
  if (d === "full") return "Fully Compliant";
  if (d === "partial") return "Partially Compliant";
  return "Not Implemented";
}
