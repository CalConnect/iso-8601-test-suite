<script setup>
import { ref, computed, watch, defineAsyncComponent } from "vue";

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
const MethodologyView = defineAsyncComponent(() => import("./views/MethodologyView.vue"));
const DeveloperGuideView = defineAsyncComponent(() => import("./views/DeveloperGuideView.vue"));
const DetailModal = defineAsyncComponent(() => import("./components/DetailModal.vue"));

const summary = ref(null);
const detail = ref(null);
const modalDetail = ref(null);
const mobileMenuOpen = ref(false);
const refDropdownOpen = ref(false);

function closeDropdowns() {
  refDropdownOpen.value = false;
}

const isDark = ref(document.documentElement.classList.contains("dark"));

function toggleTheme() {
  isDark.value = !isDark.value;
  document.documentElement.classList.toggle("dark", isDark.value);
  localStorage.setItem("theme", isDark.value ? "dark" : "light");
}

const hash = ref(location.hash);
window.addEventListener("hashchange", () => { hash.value = location.hash; });

const route = computed(() => hash.value.replace("#", "") || "/");

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
  if (r === "/methodology") return "methodology";
  if (r === "/developer-guide") return "developer-guide";
  return "dashboard";
});

const profileId = computed(() => {
  const r = route.value;
  if (r.startsWith("/profile/")) return r.replace("/profile/", "");
  return null;
});

const implId = computed(() => {
  const r = route.value;
  if (r.startsWith("/implementation/")) return r.replace("/implementation/", "");
  return null;
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
        if (req.tests[libId]) Object.assign(req.tests[libId], caps);
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

const libs = computed(() => summary.value?.libraries || []);
const reqs = computed(() => summary.value?.requirements || []);
const profiles = computed(() => summary.value?.profiles || []);
const categories = computed(() => summary.value?.categories || []);
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
  location.hash = path;
  modalDetail.value = null;
  mobileMenuOpen.value = false;
  refDropdownOpen.value = false;
}

watch(route, () => { window.scrollTo(0, 0); });
</script>

<template>
  <div class="min-h-screen flex flex-col bg-gray-950 text-gray-100">
    <!-- Topbar -->
    <nav class="sticky top-0 z-50 bg-gray-950/95 backdrop-blur-md border-b border-gray-800/60">
      <div class="max-w-[1400px] mx-auto px-4 md:px-8 h-12 flex items-center gap-4">
        <a href="#/" class="flex items-center gap-2.5 no-underline group shrink-0" @click.prevent="nav('/')">
          <img src="/logos/iso-red.svg" alt="ISO" class="h-7 w-auto" />
          <div class="hidden sm:block">
            <div class="text-sm font-bold tracking-tight leading-tight text-gray-100">ISO 8601</div>
            <div class="text-[9px] text-gray-500 font-medium tracking-wide uppercase leading-tight">Test Suite</div>
          </div>
        </a>

        <div class="w-px h-5 bg-gray-800 shrink-0"></div>

        <!-- Desktop nav -->
        <div class="hidden md:flex items-center gap-1 text-[11px]">
          <button @click="nav('/')"
            :class="['px-2.5 py-1 rounded-md font-medium transition-all', (route === '/' || currentView === 'dashboard') ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">
            Dashboard
          </button>

          <span class="text-gray-800 mx-0.5">│</span>

          <button @click="nav('/matrix')"
            :class="['px-2.5 py-1 rounded-md font-medium transition-all', route === '/matrix' ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">
            Matrix
          </button>
          <button @click="nav('/reports')"
            :class="['px-2.5 py-1 rounded-md font-medium transition-all', route === '/reports' ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">
            Reports
          </button>

          <span class="text-gray-800 mx-0.5">│</span>

          <!-- Reference dropdown -->
          <div class="relative" @mouseleave="refDropdownOpen = false">
            <button @click="refDropdownOpen = !refDropdownOpen" @mouseenter="refDropdownOpen = true"
              :class="['px-2.5 py-1 rounded-md font-medium transition-all flex items-center gap-1', ['profile-detail','requirement-detail','requirements-part','implementations','implementation-detail','implementation-report','profiles','requirements'].includes(currentView) ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">
              Reference
              <svg class="w-2.5 h-2.5 transition-transform" :class="{ 'rotate-180': refDropdownOpen }" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M6 9l6 6 6-6"/></svg>
            </button>
            <div v-if="refDropdownOpen" class="absolute top-full left-0 pt-1 w-44 z-50">
              <div class="bg-gray-900 border border-gray-700/60 rounded-lg shadow-xl py-1">
              <button @click="nav('/profiles'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-2 text-[11px] font-medium transition-colors', (route === '/profiles' || currentView === 'profile-detail') ? 'text-gray-100 bg-gray-100/5' : 'text-gray-400 hover:text-gray-200 hover:bg-gray-100/5']">
                Profiles
              </button>
              <button @click="nav('/requirements'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-2 text-[11px] font-medium transition-colors', (route === '/requirements' || currentView === 'requirement-detail' || currentView === 'requirements-part') ? 'text-gray-100 bg-gray-100/5' : 'text-gray-400 hover:text-gray-200 hover:bg-gray-100/5']">
                Requirements
              </button>
              <button @click="nav('/implementations'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-2 text-[11px] font-medium transition-colors', (route === '/implementations' || currentView === 'implementation-detail' || currentView === 'implementation-report') ? 'text-gray-100 bg-gray-100/5' : 'text-gray-400 hover:text-gray-200 hover:bg-gray-100/5']">
                Implementations
              </button>
              <div class="border-t border-gray-800/60 my-1"></div>
              <button @click="nav('/methodology'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-2 text-[11px] font-medium transition-colors', route === '/methodology' ? 'text-gray-100 bg-gray-100/5' : 'text-gray-400 hover:text-gray-200 hover:bg-gray-100/5']">
                Methodology
              </button>
              <button @click="nav('/developer-guide'); refDropdownOpen = false"
                :class="['block w-full text-left px-3 py-2 text-[11px] font-medium transition-colors', route === '/developer-guide' ? 'text-gray-100 bg-gray-100/5' : 'text-gray-400 hover:text-gray-200 hover:bg-gray-100/5']">
                Developer Guide
              </button>
              </div>
            </div>
          </div>
        </div>

        <div class="ml-auto flex items-center gap-2">
          <div class="text-[9px] text-gray-600 hidden lg:block">
            {{ reqs.length }} reqs · {{ libs.length }} libs · {{ profiles.length }} profiles
          </div>
          <button @click="nav('/about')"
            :class="['px-2.5 py-1 rounded-md text-[11px] font-medium transition-all', route === '/about' || route === '/methodology' || route === '/developer-guide' ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">
            About
          </button>
          <button
            @click="toggleTheme"
            class="w-7 h-7 rounded-md flex items-center justify-center text-gray-500 hover:text-gray-300 hover:bg-gray-100/5 transition-colors"
            :title="isDark ? 'Light mode' : 'Dark mode'"
          >
            <svg v-if="isDark" class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
            <svg v-else class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
          </button>
          <!-- Mobile menu button -->
          <button @click="mobileMenuOpen = !mobileMenuOpen"
            class="md:hidden w-7 h-7 rounded-md flex items-center justify-center text-gray-500 hover:text-gray-300 hover:bg-gray-100/5 transition-colors">
            <svg v-if="!mobileMenuOpen" class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16"/></svg>
            <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M6 18L18 6M6 6l12 12"/></svg>
          </button>
        </div>
      </div>

      <!-- Mobile dropdown menu -->
      <div v-if="mobileMenuOpen" class="md:hidden border-t border-gray-800/60 bg-gray-950/98 backdrop-blur-md">
        <div class="px-4 py-3 space-y-1">
          <button @click="nav('/')" :class="['block w-full text-left px-3 py-2 rounded-md text-xs font-medium transition-all', (route === '/' || currentView === 'dashboard') ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">Dashboard</button>
          <div class="py-1 px-3 text-[9px] text-gray-600 uppercase tracking-wider font-bold">Results</div>
          <button @click="nav('/matrix')" :class="['block w-full text-left px-3 py-2 rounded-md text-xs font-medium transition-all pl-6', route === '/matrix' ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">Matrix</button>
          <button @click="nav('/reports')" :class="['block w-full text-left px-3 py-2 rounded-md text-xs font-medium transition-all pl-6', route === '/reports' ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">Reports</button>
          <div class="py-1 px-3 text-[9px] text-gray-600 uppercase tracking-wider font-bold">Reference</div>
          <button @click="nav('/profiles')" :class="['block w-full text-left px-3 py-2 rounded-md text-xs font-medium transition-all pl-6', (route === '/profiles' || currentView === 'profile-detail') ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">Profiles</button>
          <button @click="nav('/requirements')" :class="['block w-full text-left px-3 py-2 rounded-md text-xs font-medium transition-all pl-6', (route === '/requirements' || currentView === 'requirement-detail' || currentView === 'requirements-part') ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">Requirements</button>
          <button @click="nav('/implementations')" :class="['block w-full text-left px-3 py-2 rounded-md text-xs font-medium transition-all pl-6', (route === '/implementations' || currentView === 'implementation-detail' || currentView === 'implementation-report') ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">Implementations</button>
          <button @click="nav('/methodology')" :class="['block w-full text-left px-3 py-2 rounded-md text-xs font-medium transition-all pl-6', route === '/methodology' ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">Methodology</button>
          <button @click="nav('/developer-guide')" :class="['block w-full text-left px-3 py-2 rounded-md text-xs font-medium transition-all pl-6', route === '/developer-guide' ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">Developer Guide</button>
          <div class="py-1 px-3 text-[9px] text-gray-600 uppercase tracking-wider font-bold">Info</div>
          <button @click="nav('/about')" :class="['block w-full text-left px-3 py-2 rounded-md text-xs font-medium transition-all pl-6', route === '/about' ? 'bg-gray-100/10 text-gray-100' : 'text-gray-500 hover:text-gray-300 hover:bg-gray-100/5']">About</button>
        </div>
      </div>
    </nav>

    <!-- Content -->
    <main class="flex-1">
      <div v-if="!summary" class="flex items-center justify-center py-32">
        <div class="text-center">
          <div class="inline-block w-6 h-6 border-2 border-gray-600 border-t-gray-100 rounded-full animate-spin mb-4"></div>
          <p class="text-gray-500 text-sm">Loading test suite…</p>
        </div>
      </div>
      <template v-else>
        <DashboardView
          v-if="currentView === 'dashboard'"
          :libs="libs"
          :reqs="reqs"
          :profiles="profiles"
          :categories="categories"
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
        <MethodologyView
          v-if="currentView === 'methodology'"
          @navigate="nav"
        />
        <DeveloperGuideView
          v-if="currentView === 'developer-guide'"
          @navigate="nav"
        />
      </template>
    </main>

    <!-- Footer -->
    <footer class="border-t border-gray-800/60 py-4">
      <div class="max-w-[1400px] mx-auto px-4 md:px-8 flex flex-wrap items-center justify-between gap-2 text-[10px] text-gray-600">
        <span>ISO/TC 154/WG 5 — ISO 8601 Machine-Readable Test Suite</span>
        <span v-if="generatedAt">Generated {{ generatedAt }}</span>
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
