// Shared stats computation functions.

export function libStats(lib, reqs) {
  let pass = 0, partial = 0, fail = 0, notSupported = 0, total = 0, notDeclared = 0;
  const targetIds = new Set((lib.target_profiles || []).map(p => p.id));
  reqs.forEach(r => {
    const caps = r.tests?.[lib.id];
    if (!caps) return;
    const reqProfileIds = (r.profiles || []).map(p => p.id);
    const applicable = reqProfileIds.length === 0 || reqProfileIds.some(id => targetIds.has(id));
    if (!applicable) { notDeclared++; return; }
    Object.values(caps).forEach(c => {
      total++;
      if (c.status === "pass") pass++;
      else if (c.status === "partial") partial++;
      else if (c.status === "not-supported") notSupported++;
      else fail++;
    });
  });
  return { pass, partial, fail, notSupported, total, notDeclared, pct: total ? Math.round(pass / total * 100) : 0 };
}

export function reqStats(req, libs) {
  let pass = 0, total = 0;
  libs.forEach(lib => {
    const caps = req.tests?.[lib.id];
    if (!caps) return;
    Object.values(caps).forEach(cap => {
      total += cap.total || 0;
      pass += cap.pass || 0;
    });
  });
  return { pass, total, pct: total ? Math.round(pass / total * 100) : 0 };
}

export function reqStatsBreakdown(req, libs) {
  let pass = 0, fail = 0, notSupported = 0, total = 0;
  libs.forEach(lib => {
    const caps = req.tests?.[lib.id];
    if (!caps) return;
    Object.values(caps).forEach(cap => {
      cap.details?.forEach(d => {
        total++;
        if (d.result === "pass") pass++;
        else if (d.result === "not-supported") notSupported++;
        else fail++;
      });
    });
  });
  return { pass, fail, notSupported, total, pct: total ? Math.round(pass / total * 100) : 0 };
}

export function profilePct(p) {
  const best = p.adapter_results?.reduce((a, b) =>
    (b.test_total ? b.test_pass / b.test_total : 0) > (a.test_total ? a.test_pass / a.test_total : 0) ? b : a,
    { test_pass: 0, test_total: 0 }
  );
  return best.test_total ? Math.round(best.test_pass / best.test_total * 100) : 0;
}

export function profileAdapterPct(adapterResult) {
  const total = adapterResult?.test_total || 0;
  const pass = adapterResult?.test_pass || 0;
  return total ? Math.round(pass / total * 100) : 0;
}

export function pctColor(pct) {
  if (pct >= 60) return "text-jade";
  if (pct >= 30) return "text-amber";
  return "text-rust";
}

export function pctBarColor(pct) {
  if (pct >= 60) return "bg-jade";
  if (pct >= 30) return "bg-amber";
  return "bg-rust";
}

export function profileBarColor(pct) {
  if (pct >= 40) return "bg-jade";
  if (pct >= 15) return "bg-amber";
  return "bg-rust";
}

export function meanPassPct(libs, reqs) {
  let totalPass = 0, total = 0;
  libs.forEach(lib => {
    const s = libStats(lib, reqs);
    totalPass += s.pass;
    total += s.total;
  });
  return total ? Math.round((totalPass / total) * 100) : 0;
}

export function familyStatsByName(familyStats, name) {
  if (!familyStats || !name) return null;
  return familyStats.find(fs => fs.family === name) || null;
}

export function stabilityTone(stability) {
  if (stability === "stable" || stability === "single") return "jade";
  if (stability === "minor") return "amber";
  return "rust";
}

export function stabilityLabel(fs) {
  if (!fs) return "";
  if (fs.stability === "single") return "single version";
  if (fs.delta_count === 0) return "stable across versions";
  if (fs.delta_count === 1) return "1 test diverges";
  return `${fs.delta_count} tests diverge`;
}

export function overallDetermination(statuses) {
  if (!statuses.length) return "none";
  if (statuses.every(s => s === "pass")) return "full";
  if (statuses.some(s => s === "pass" || s === "partial")) return "partial";
  return "none";
}
