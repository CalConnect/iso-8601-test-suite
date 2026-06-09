// Shared status styling functions — single source of truth for pass/partial/fail visuals.

export function statusColor(s) {
  if (s === "pass") return "text-emerald-600 dark:text-emerald-400";
  if (s === "partial") return "text-amber-600 dark:text-amber-400";
  if (s === "fail") return "text-red-500 dark:text-red-400";
  return "text-gray-500";
}

export function statusBg(s) {
  if (s === "pass") return "bg-emerald-500/10 border-emerald-500/20";
  if (s === "partial") return "bg-amber-500/10 border-amber-500/20";
  if (s === "fail") return "bg-red-500/10 border-red-500/20";
  return "bg-gray-800/30 border-gray-700/30";
}

export function statusIcon(s) {
  if (s === "pass") return "✓";
  if (s === "partial") return "≈";
  if (s === "fail") return "✗";
  return "—";
}

export function detClass(d) {
  if (d === "full") return "text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 border-emerald-500/20";
  if (d === "partial") return "text-amber-600 dark:text-amber-400 bg-amber-500/10 border-amber-500/20";
  return "text-gray-500 bg-gray-800/30 border-gray-700/30";
}

export function detLabel(d) {
  if (d === "full") return "Fully Compliant";
  if (d === "partial") return "Partially Compliant";
  return "Not Implemented";
}
