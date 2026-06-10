// Shared stats computation functions.

export function libStats(lib, reqs) {
  let pass = 0, partial = 0, fail = 0, total = 0, notDeclared = 0;
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
      else fail++;
    });
  });
  return { pass, partial, fail, total, notDeclared, pct: total ? Math.round(pass / total * 100) : 0 };
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
  if (pct >= 60) return "text-emerald-600 dark:text-emerald-400";
  if (pct >= 30) return "text-amber-600 dark:text-amber-400";
  return "text-red-500 dark:text-red-400";
}

export function pctBarColor(pct) {
  if (pct >= 60) return "bg-emerald-500";
  if (pct >= 30) return "bg-amber-500";
  return "bg-red-500";
}

export function profileBarColor(pct) {
  if (pct >= 40) return "bg-emerald-500";
  if (pct >= 15) return "bg-amber-500";
  return "bg-red-500";
}

export function overallDetermination(perLibrary) {
  const statuses = perLibrary.map(l => l.status);
  if (statuses.every(s => s === "pass")) return "full";
  if (statuses.some(s => s === "pass" || s === "partial")) return "partial";
  return "none";
}
