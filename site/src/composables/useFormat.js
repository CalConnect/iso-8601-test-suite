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

export function libVersionLabel(lib) {
  const m = lib.name.match(/(\d+(?:\.\d+)*)/);
  return m ? m[1] : lib.version || lib.id;
}

export function groupByFamily(libs) {
  const groups = [];
  const index = new Map();
  for (const lib of libs) {
    const key = lib.family || lib.language || "Other";
    if (!index.has(key)) {
      const g = { family: key, logo: lib.logo, language: lib.language, versions: [] };
      index.set(key, g);
      groups.push(g);
    }
    index.get(key).versions.push(lib);
  }
  return groups;
}

export function sortLibsNewestFirst(libs) {
  const famIdx = new Map();
  let next = 0;
  libs.forEach(lib => {
    const f = lib.family || lib.language || "Other";
    if (!famIdx.has(f)) famIdx.set(f, next++);
  });
  return libs
    .map((lib, origIdx) => ({ lib, origIdx }))
    .sort((a, b) => {
      const fa = famIdx.get(a.lib.family || a.lib.language || "Other");
      const fb = famIdx.get(b.lib.family || b.lib.language || "Other");
      if (fa !== fb) return fa - fb;
      return b.origIdx - a.origIdx;
    })
    .map(x => x.lib);
}
