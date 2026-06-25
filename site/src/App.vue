<script setup>
import { ref, computed, watch, onMounted, onUnmounted, defineAsyncComponent } from "vue";
import { sortLibsNewestFirst } from "./composables/useFormat";

const DashboardView = defineAsyncComponent(() => import("./views/DashboardView.vue"));
const MatrixView = defineAsyncComponent(() => import("./views/MatrixView.vue"));
const ProfilesView = defineAsyncComponent(() => import("./views/ProfilesView.vue"));
const ProfileDetailView = defineAsyncComponent(() => import("./views/ProfileDetailView.vue"));
const ImplementationsView = defineAsyncComponent(() => import("./views/ImplementationsView.vue"));
const ImplementationDetailView = defineAsyncComponent(() => import("./views/ImplementationDetailView.vue"));
const RequirementsView = defineAsyncComponent(() => import("./views/RequirementsView.vue"));
const RequirementsPartView = defineAsyncComponent(() => import("./views/RequirementsPartView.vue"));
const RequirementDetailView = defineAsyncComponent(() => import("./views/RequirementDetailView.vue"));
const ReportsView = defineAsyncComponent(() => import("./views/ReportsView.vue"));
const ImplementationReportView = defineAsyncComponent(() => import("./views/ImplementationReportView.vue"));
const AboutView = defineAsyncComponent(() => import("./views/AboutView.vue"));
const DocsView = defineAsyncComponent(() => import("./views/DocsView.vue"));
const MethodologyView = defineAsyncComponent(() => import("./views/MethodologyView.vue"));
const DeveloperGuideView = defineAsyncComponent(() => import("./views/DeveloperGuideView.vue"));
const AdapterRulesView = defineAsyncComponent(() => import("./views/AdapterRulesView.vue"));
const DetailModal = defineAsyncComponent(() => import("./components/DetailModal.vue"));

const summary = ref(null);
const detail = ref(null);
const modalDetail = ref(null);
const mobileMenuOpen = ref(false);
const refDropdownOpen = ref(false);
const clock = ref({ h: "--", m: "--", s: "--", offset: "+00:00", tz: "UTC", utcIso: "", localIso: "" });
let clockTimer = null;

function pad(n, w = 2) {
  return String(n).padStart(w, "0");
}

function tickClock() {
  const d = new Date();
  const offsetMin = -d.getTimezoneOffset();
  const sign = offsetMin >= 0 ? "+" : "-";
  const abs = Math.abs(offsetMin);
  const offset = `${sign}${pad(Math.floor(abs / 60))}:${pad(abs % 60)}`;
  const tz = (Intl.DateTimeFormat().resolvedOptions().timeZone || "local").replace(/_/g, " ");

  clock.value = {
    h: pad(d.getHours()),
    m: pad(d.getMinutes()),
    s: pad(d.getSeconds()),
    offset,
    tz,
    utcIso:
      `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}` +
      `T${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}Z`,
    localIso:
      `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
      `T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}${offset}`,
  };
}

onMounted(() => {
  tickClock();
  clockTimer = setInterval(tickClock, 1000);
});

onUnmounted(() => {
  if (clockTimer) clearInterval(clockTimer);
});

function closeDropdowns() {
  refDropdownOpen.value = false;
}

const isDark = ref(document.documentElement.classList.contains("dark"));

function toggleTheme() {
  isDark.value = !isDark.value;
  document.documentElement.classList.toggle("dark", isDark.value);
  localStorage.setItem("theme", isDark.value ? "dark" : "light");
}

const currentPath = () => location.pathname || "/";
const hash = ref(currentPath());
window.addEventListener("popstate", () => { hash.value = currentPath(); });

const route = computed(() => hash.value || "/");

const needsDetail = computed(() => {
  const r = route.value;
  return r === "/matrix" ||
    r.startsWith("/profile/") ||
    r.startsWith("/requirement/") ||
    r.startsWith("/implementation/");
});

const currentView = computed(() => {
  const r = route.value;
  if (r === "/" || r === "") return "dashboard";
  if (r === "/matrix") return "matrix";
  if (r === "/profiles") return "profiles";
  if (r.startsWith("/profile/")) return "profile-detail";
  if (r === "/requirements") return "requirements";
  if (r.startsWith("/requirements/")) return "requirements-part";
  if (r.startsWith("/requirement/")) return "requirement-detail";
  if (r === "/implementations") return "implementations";
  if (r.match(/^\/implementation\/[^/]+\/report\//)) return "implementation-report";
  if (r.startsWith("/implementation/")) return "implementation-detail";
  if (r === "/reports") return "reports";
  if (r === "/about") return "about";
  if (r.startsWith("/docs/")) return "docs";
  if (r === "/methodology") return "methodology";
  if (r === "/developer-guide") return "developer-guide";
  if (r === "/adapter-rules") return "adapter-rules";
  return "dashboard";
});

const profileId = computed(() => {
  const r = route.value;
  if (r.startsWith("/profile/")) return r.replace("/profile/", "");
  return null;
});

const implId = computed(() => {
  const r = route.value;
  const m = r.match(/^\/implementation\/([^/]+)/);
  return m ? m[1] : null;
});

async function loadSummary() {
  try {
    const r = await fetch("/summary.json");
    if (!r.ok) throw 0;
    summary.value = await r.json();
  } catch {}
}

async function loadDetail() {
  if (detail.value) return;
  try {
    const r = await fetch("/detail.json");
    if (!r.ok) throw 0;
    const d = await r.json();
    if (summary.value) mergeDetail(d);
    detail.value = d;
  } catch {}
}

function mergeDetail(d) {
  const reqMap = {};
  (d.requirements || []).forEach(r => { reqMap[r.id] = r.tests; });
  summary.value.requirements.forEach(req => {
    const dt = reqMap[req.id];
    if (dt) {
      Object.entries(dt).forEach(([libId, caps]) => {
        if (!req.tests[libId]) return;
        Object.entries(caps).forEach(([capKey, capVal]) => {
          if (req.tests[libId][capKey]) Object.assign(req.tests[libId][capKey], capVal);
        });
      });
    }
  });
  const profMap = {};
  (d.profiles || []).forEach(p => { profMap[p.id] = p.traceability; });
  summary.value.profiles.forEach(prof => {
    if (profMap[prof.id]) prof.traceability = profMap[prof.id];
  });
}

loadSummary();

watch(needsDetail, (v) => { if (v) loadDetail(); }, { immediate: true });

const libs = computed(() => sortLibsNewestFirst(summary.value?.libraries || []));
const reqs = computed(() => summary.value?.requirements || []);
const profiles = computed(() => summary.value?.profiles || []);
const categories = computed(() => summary.value?.categories || []);
const familyStats = computed(() => summary.value?.family_stats || []);
const generatedAt = computed(() =>
  summary.value ? new Date(summary.value.generated_at).toLocaleString() : ""
);

const activeProfile = computed(() => {
  if (!profileId.value) return null;
  return profiles.value.find(p => p.id === profileId.value || p.id === `profile:${profileId.value}`);
});

const activeImpl = computed(() => {
  if (!implId.value) return null;
  return libs.value.find(l => l.id === implId.value);
});

const reportProfileId = computed(() => {
  const r = route.value;
  const m = r.match(/^\/implementation\/([^/]+)\/report\/(.+)$/);
  return m ? m[2] : null;
});

const docsSlug = computed(() => {
  const r = route.value;
  if (!r.startsWith("/docs/")) return null;
  return r.replace("/docs/", "").replace(/\/$/, "");
});

const reportProfile = computed(() => {
  if (!reportProfileId.value) return null;
  return profiles.value.find(p =>
    p.id === reportProfileId.value ||
    p.id === `profile:${reportProfileId.value}`
  );
});

const activeReq = computed(() => {
  const r = route.value;
  if (!r.startsWith("/requirement/")) return null;
  const rid = r.replace("/requirement/", "");
  return reqs.value.find(r => r.id === rid || r.id === `req:${rid}`);
});

const activeReqSection = computed(() => {
  const r = route.value;
  if (!r.startsWith("/requirements/")) return null;
  return r.replace("/requirements/", "");
});

function nav(path) {
  history.pushState(null, "", path);
  hash.value = path;
  modalDetail.value = null;
  mobileMenuOpen.value = false;
  refDropdownOpen.value = false;
}

watch(route, () => { window.scrollTo(0, 0); });
</script>

<template>
  <div class="min-h-screen flex flex-col bg-paper text-ink">
    <!-- Topbar -->
    <nav class="sticky top-0 z-50 bg-paper/95 backdrop-blur-md border-b border-rule">
      <div class="max-w-[1400px] mx-auto px-4 md:px-8 h-16 flex items-center gap-4">
        <a @click.prevent="nav('/')" class="flex items-center gap-3 no-underline group shrink-0 cursor-pointer">
          <img src="/logos/iso-red.svg" alt="ISO" class="h-7 w-auto" />
          <div class="hidden sm:block leading-none">
            <div class="font-display text-lg font-medium tracking-tight text-ink">ISO 8601</div>
            <div class="clause-label mt-0.5">Conformance Test Suite</div>
          </div>
        </a>

        <div class="w-px h-6 bg-rule shrink-0 hidden md:block"></div>

        <!-- Desktop nav -->
        <div class="hidden md:flex items-center gap-0.5 text-sm">
          <button @click="nav('/')"
            :class="['px-2.5 py-1 font-mono text-xs uppercase tracking-wider transition-colors', (route === '/' || currentView === 'dashboard') ? 'text-accent' : 'text-ink-muted hover:text-ink']">
            Dashboard
          </button>

          <span class="text-rule mx-1 text-xs">·</span>

          <button @click="nav('/matrix')"
            :class="['px-2.5 py-1 font-mono text-xs uppercase tracking-wider transition-colors', route === '/matrix' ? 'text-accent' : 'text-ink-muted hover:text-ink']">
            Matrix
          </button>
          <button @click="nav('/reports')"
            :class="['px-2.5 py-1 font-mono text-xs uppercase tracking-wider transition-colors', route === '/reports' ? 'text-accent' : 'text-ink-muted hover:text-ink']">
            Reports
          </button>

          <span class="text-rule mx-1 text-xs">·</span>

          <!-- Reference dropdown -->
          <div class="relative" @mouseleave="refDropdownOpen = false">
            <button @click="refDropdownOpen = !refDropdownOpen" @mouseenter="refDropdownOpen = true"
              :class="['px-2.5 py-1 font-mono text-xs uppercase tracking-wider transition-colors flex items-center gap-1.5', ['profile-detail','requirement-detail','requirements-part','implementations','implementation-detail','implementation-report','profiles','requirements'].includes(currentView) ? 'text-accent' : 'text-ink-muted hover:text-ink']">
              Reference
              <svg class="w-2.5 h-2.5 transition-transform" :class="{ 'rotate-180': refDropdownOpen }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M6 9l6 6 6-6"/></svg>
            </button>
            <div v-if="refDropdownOpen" class="absolute top-full left-0 pt-1 w-48 z-50">
              <div class="surface shadow-xl py-1">
              <button @click="nav('/profiles'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-1.5 font-mono text-xs uppercase tracking-wider transition-colors', (route === '/profiles' || currentView === 'profile-detail') ? 'text-accent bg-surface-2' : 'text-ink-muted hover:text-ink hover:bg-surface-2']">
                Profiles
              </button>
              <button @click="nav('/requirements'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-1.5 font-mono text-xs uppercase tracking-wider transition-colors', (route === '/requirements' || currentView === 'requirement-detail' || currentView === 'requirements-part') ? 'text-accent bg-surface-2' : 'text-ink-muted hover:text-ink hover:bg-surface-2']">
                Requirements
              </button>
              <button @click="nav('/implementations'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-1.5 font-mono text-xs uppercase tracking-wider transition-colors', (route === '/implementations' || currentView === 'implementation-detail' || currentView === 'implementation-report') ? 'text-accent bg-surface-2' : 'text-ink-muted hover:text-ink hover:bg-surface-2']">
                Implementations
              </button>
              <div class="border-t border-rule-soft my-1"></div>
              <button @click="nav('/methodology'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-1.5 font-mono text-xs uppercase tracking-wider transition-colors', route === '/methodology' ? 'text-accent bg-surface-2' : 'text-ink-muted hover:text-ink hover:bg-surface-2']">
                Methodology
              </button>
              <button @click="nav('/developer-guide'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-1.5 font-mono text-xs uppercase tracking-wider transition-colors', route === '/developer-guide' ? 'text-accent bg-surface-2' : 'text-ink-muted hover:text-ink hover:bg-surface-2']">
                Developer Guide
              </button>
              <button @click="nav('/adapter-rules'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-1.5 font-mono text-xs uppercase tracking-wider transition-colors', route === '/adapter-rules' ? 'text-accent bg-surface-2' : 'text-ink-muted hover:text-ink hover:bg-surface-2']">
                Adapter Rules
              </button>
              </div>
            </div>
          </div>
        </div>

        <div class="ml-auto flex items-center gap-3">
          <!-- Live clock (scientific instrument) -->
          <div class="hidden lg:flex flex-col items-end leading-none">
            <div class="live-clock text-sm text-ink flex items-center" :title="clock.utcIso">
              <span class="tabular-nums">{{ clock.h }}</span>
              <span class="clock-blink">:</span>
              <span class="tabular-nums">{{ clock.m }}</span>
              <span class="clock-blink">:</span>
              <span class="tabular-nums text-accent">{{ clock.s }}</span>
            </div>
            <div class="clause-label mt-1">UTC{{ clock.offset }} · {{ clock.tz }}</div>
          </div>

          <div class="hidden lg:block w-px h-6 bg-rule"></div>

          <div class="hidden md:flex flex-col leading-none">
            <div class="font-mono text-xs text-ink">
              <span class="tabular-nums">{{ reqs.length }}</span>·<span class="tabular-nums">{{ libs.length }}</span>·<span class="tabular-nums">{{ profiles.length }}</span>
            </div>
            <div class="clause-label mt-1">reqs·libs·profiles</div>
          </div>

          <button @click="nav('/about')"
            :class="['px-2.5 py-1 font-mono text-xs uppercase tracking-wider transition-colors', route === '/about' ? 'text-accent' : 'text-ink-muted hover:text-ink']">
            About
          </button>
          <button
            @click="toggleTheme"
            class="w-7 h-7 flex items-center justify-center text-ink-muted hover:text-ink transition-colors"
            :title="isDark ? 'Light mode' : 'Dark mode'"
          >
            <svg v-if="isDark" class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
            <svg v-else class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
          </button>
          <!-- Mobile menu button -->
          <button @click="mobileMenuOpen = !mobileMenuOpen"
            class="md:hidden w-7 h-7 flex items-center justify-center text-ink-muted hover:text-ink transition-colors">
            <svg v-if="!mobileMenuOpen" class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16"/></svg>
            <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M6 18L18 6M6 6l12 12"/></svg>
          </button>
        </div>
      </div>

      <!-- Mobile dropdown menu -->
      <div v-if="mobileMenuOpen" class="md:hidden border-t border-rule bg-paper/98 backdrop-blur-md">
        <div class="px-4 py-3 space-y-1">
          <button @click="nav('/')" :class="['block w-full text-left px-3 py-1.5 font-mono text-xs uppercase tracking-wider transition-colors', (route === '/' || currentView === 'dashboard') ? 'text-accent' : 'text-ink-muted hover:text-ink']">Dashboard</button>
          <div class="py-1 px-3 clause-label">Results</div>
          <button @click="nav('/matrix')" :class="['block w-full text-left px-3 py-1.5 pl-6 font-mono text-xs uppercase tracking-wider transition-colors', route === '/matrix' ? 'text-accent' : 'text-ink-muted hover:text-ink']">Matrix</button>
          <button @click="nav('/reports')" :class="['block w-full text-left px-3 py-1.5 pl-6 font-mono text-xs uppercase tracking-wider transition-colors', route === '/reports' ? 'text-accent' : 'text-ink-muted hover:text-ink']">Reports</button>
          <div class="py-1 px-3 clause-label">Reference</div>
          <button @click="nav('/profiles')" :class="['block w-full text-left px-3 py-1.5 pl-6 font-mono text-xs uppercase tracking-wider transition-colors', (route === '/profiles' || currentView === 'profile-detail') ? 'text-accent' : 'text-ink-muted hover:text-ink']">Profiles</button>
          <button @click="nav('/requirements')" :class="['block w-full text-left px-3 py-1.5 pl-6 font-mono text-xs uppercase tracking-wider transition-colors', (route === '/requirements' || currentView === 'requirement-detail' || currentView === 'requirements-part') ? 'text-accent' : 'text-ink-muted hover:text-ink']">Requirements</button>
          <button @click="nav('/implementations')" :class="['block w-full text-left px-3 py-1.5 pl-6 font-mono text-xs uppercase tracking-wider transition-colors', (route === '/implementations' || currentView === 'implementation-detail' || currentView === 'implementation-report') ? 'text-accent' : 'text-ink-muted hover:text-ink']">Implementations</button>
          <button @click="nav('/methodology')" :class="['block w-full text-left px-3 py-1.5 pl-6 font-mono text-xs uppercase tracking-wider transition-colors', route === '/methodology' ? 'text-accent' : 'text-ink-muted hover:text-ink']">Methodology</button>
          <button @click="nav('/developer-guide')" :class="['block w-full text-left px-3 py-1.5 pl-6 font-mono text-xs uppercase tracking-wider transition-colors', route === '/developer-guide' ? 'text-accent' : 'text-ink-muted hover:text-ink']">Developer Guide</button>
          <button @click="nav('/adapter-rules')" :class="['block w-full text-left px-3 py-1.5 pl-6 font-mono text-xs uppercase tracking-wider transition-colors', route === '/adapter-rules' ? 'text-accent' : 'text-ink-muted hover:text-ink']">Adapter Rules</button>
          <div class="py-1 px-3 clause-label">Info</div>
          <button @click="nav('/about')" :class="['block w-full text-left px-3 py-1.5 pl-6 font-mono text-xs uppercase tracking-wider transition-colors', route === '/about' ? 'text-accent' : 'text-ink-muted hover:text-ink']">About</button>
        </div>
      </div>
    </nav>

    <!-- Content -->
    <main class="flex-1">
      <div v-if="!summary" class="flex items-center justify-center py-32">
        <div class="text-center">
          <div class="inline-block w-6 h-6 border-2 border-rule border-t-accent rounded-full animate-spin mb-4"></div>
          <p class="clause-label">Loading test suite…</p>
        </div>
      </div>
      <template v-else>
        <div :key="route" class="view-enter">
        <DashboardView
          v-if="currentView === 'dashboard'"
          :libs="libs"
          :reqs="reqs"
          :profiles="profiles"
          :categories="categories"
          :family-stats="familyStats"
          @navigate="nav"
        />
        <MatrixView
          v-if="currentView === 'matrix'"
          :libs="libs"
          :reqs="reqs"
          :categories="categories"
          :profiles="profiles"
          @open-detail="modalDetail = $event"
        />
        <ProfilesView
          v-if="currentView === 'profiles'"
          :profiles="profiles"
          :libs="libs"
          @navigate="nav"
        />
        <ProfileDetailView
          v-if="currentView === 'profile-detail' && activeProfile"
          :profile="activeProfile"
          :libs="libs"
          @open-detail="modalDetail = $event"
          @navigate="nav"
        />
        <ImplementationsView
          v-if="currentView === 'implementations'"
          :libs="libs"
          :profiles="profiles"
          :reqs="reqs"
          :family-stats="familyStats"
          @navigate="nav"
        />
        <RequirementsView
          v-if="currentView === 'requirements'"
          :reqs="reqs"
          :libs="libs"
          :profiles="profiles"
          @navigate="nav"
        />
        <RequirementsPartView
          v-if="currentView === 'requirements-part' && activeReqSection"
          :section="activeReqSection"
          :reqs="reqs"
          :libs="libs"
          :profiles="profiles"
          @navigate="nav"
        />
        <RequirementDetailView
          v-if="currentView === 'requirement-detail' && activeReq"
          :req="activeReq"
          :libs="libs"
          :reqs="reqs"
          :profiles="profiles"
          @navigate="nav"
        />
        <ImplementationDetailView
          v-if="currentView === 'implementation-detail' && activeImpl"
          :lib="activeImpl"
          :profiles="profiles"
          :reqs="reqs"
          :libs="libs"
          @navigate="nav"
        />
        <ImplementationReportView
          v-if="currentView === 'implementation-report' && activeImpl && reportProfile"
          :lib="activeImpl"
          :profile="reportProfile"
          :libs="libs"
          @navigate="nav"
        />
        <ReportsView
          v-if="currentView === 'reports'"
          :libs="libs"
          :reqs="reqs"
        />
        <AboutView
          v-if="currentView === 'about'"
          @navigate="nav"
        />
        <DocsView
          v-if="currentView === 'docs' && docsSlug"
          :slug="docsSlug"
          @navigate="nav"
        />
        <MethodologyView
          v-if="currentView === 'methodology'"
          @navigate="nav"
        />
        <DeveloperGuideView
          v-if="currentView === 'developer-guide'"
          @navigate="nav"
        />
        <AdapterRulesView
          v-if="currentView === 'adapter-rules'"
          @navigate="nav"
        />
        </div>
      </template>
    </main>

    <!-- Footer -->
    <footer class="border-t border-rule">
      <div class="max-w-[1400px] mx-auto px-4 md:px-8 py-4 flex flex-wrap items-center justify-between gap-4">
        <div class="flex flex-col leading-none">
          <span class="font-display text-sm text-ink">ISO/TC 154/WG 5</span>
          <span class="clause-label mt-1">ISO 8601 Machine-Readable Test Suite</span>
        </div>
        <div class="flex flex-wrap items-center gap-6 leading-none">
          <div class="hidden sm:flex flex-col items-end">
            <span class="font-mono text-xs text-ink-muted tabular-nums">{{ clock.localIso }}</span>
            <span class="clause-label mt-1">local · {{ clock.tz }}</span>
          </div>
          <div class="hidden md:flex flex-col items-end">
            <span class="font-mono text-xs text-ink-muted tabular-nums">{{ clock.utcIso }}</span>
            <span class="clause-label mt-1">coordinated universal time</span>
          </div>
          <div v-if="generatedAt" class="flex flex-col items-end">
            <span class="live-clock text-xs text-ink-faint">{{ generatedAt }}</span>
            <span class="clause-label mt-1">data generated</span>
          </div>
        </div>
      </div>
    </footer>

    <!-- Detail modal -->
    <DetailModal
      v-if="modalDetail"
      :detail="modalDetail"
      :libs="libs"
      @close="modalDetail = null"
    />
  </div>
</template>
