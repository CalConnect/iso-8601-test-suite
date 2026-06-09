// Shared formatting utilities.

export function trunc(s, n) {
  return s && s.length > n ? s.slice(0, n) + "…" : s || "";
}

export function fmtTag(f) {
  if (!f || f === "any") return "";
  return f === "basic" ? "BAS" : f === "extended" ? "EXT" : f.toUpperCase();
}

export function typeLabel(t) {
  if (t === "parse_general") return "Parse";
  if (t === "construct") return "Construct";
  if (t === "arithmetic") return "Arithmetic";
  if (t === "round_trip") return "Round Trip";
  return t;
}

export function capTypeLabel(t) {
  return typeLabel(t);
}

export function clauseUrl(urn) {
  if (!urn) return null;
  return urn.replace("urn:iso:", "http://standards.iso.org/").replace(/:/g, "/").toLowerCase();
}

export function formatValue(v) {
  if (v === null || v === undefined) return "";
  if (typeof v === "string") return v;
  if (typeof v === "boolean") return v ? "true" : "false";
  return JSON.stringify(v, null, 2);
}

export function libShortName(name) {
  return name.split(" ").slice(0, 2).join(" ");
}
