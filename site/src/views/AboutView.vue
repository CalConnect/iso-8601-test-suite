<script setup>
const emit = defineEmits(["navigate"]);

const audiences = [
  {
    key: "standards-authors",
    title: "Standards authors",
    blurb:
      "ISO/TC 154, CalConnect TC DATETIME, or anyone reviewing the standard. Use the suite to spot ambiguous normative text via cross-implementation failure clusters.",
    docSlug: "standards-authors",
    dashboardPath: "/matrix",
    dashboardLabel: "Open the capability matrix",
    clause: "§ A.01",
  },
  {
    key: "implementers",
    title: "Library maintainers",
    blurb:
      "You write or maintain a date/time library. Find out what your library conforms to, where it fails, and how to fix common patterns.",
    docSlug: "implementers",
    dashboardPath: "/implementations",
    dashboardLabel: "Browse implementations",
    clause: "§ A.02",
  },
  {
    key: "profile-authors",
    title: "Profile authors",
    blurb:
      "You maintain RFC 3339, W3C Datetime, EDTF, or your own subset. Learn how to formalize a profile and check its interoperability.",
    docSlug: "profile-authors",
    dashboardPath: "/profiles",
    dashboardLabel: "See profile results",
    clause: "§ A.03",
  },
  {
    key: "application-developers",
    title: "Application developers",
    blurb:
      "You're choosing a date/time library for a project. See what ISO 8601 conformance means in practice and which libraries to rely on per use case.",
    docSlug: "application-developers",
    dashboardPath: "/implementations",
    dashboardLabel: "Compare libraries",
    clause: "§ A.04",
  },
  {
    key: "contributors",
    title: "Contributors",
    blurb:
      "You want to add a test, fix a bug, or write an adapter. Task index, conventions, and the path from change to merged PR.",
    docSlug: "contributors",
    dashboardPath: "/methodology",
    dashboardLabel: "Read the methodology",
    clause: "§ A.05",
  },
  {
    key: "curious",
    title: "Just curious",
    blurb:
      "You want the one-minute tour of what ISO 8601 covers and how libraries implement it. Start at the dashboard, then dive deeper when ready.",
    docSlug: null,
    dashboardPath: "/",
    dashboardLabel: "Open the dashboard",
    clause: "§ A.06",
  },
];

const concepts = [
  { slug: "conformance-model", title: "The conformance model", sub: "Requirements, classes, profiles, declared vs. not-declared" },
  { slug: "test-types", title: "Test types", sub: "Validity, parsing, generation, equivalence, arithmetic, round-trip" },
  { slug: "identifier-scheme", title: "Identifier scheme", sub: "CURIE-style local IDs and RFC 5141 URN clause references" },
];
</script>

<template>
  <div class="max-w-[1200px] mx-auto px-4 md:px-8 py-10 md:py-14">

    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">About</span>
    </div>

    <!-- Hero -->
    <section class="relative mb-16">
      <div class="iso-watermark hidden md:block">
        <span style="top: 12%; left: 8%;">2026-04-12T23:20:30Z</span>
        <span style="top: 70%; right: 12%;">CalConnect / TC DATETIME</span>
      </div>
      <div class="relative">
        <div class="flex items-baseline gap-3 mb-6">
          <span class="clause-label clause-label-accent">§ 00</span>
          <span class="clause-label">Audience router</span>
        </div>
        <h1 class="display-hero text-4xl md:text-6xl mb-6 max-w-4xl">
          About the <em>ISO 8601</em><br/>test suite.
        </h1>
        <p class="text-ink-soft text-base md:text-lg max-w-2xl leading-relaxed">
          A machine-readable conformance test suite for the ISO 8601 family of
          date/time standards, developed by <strong class="text-ink">CalConnect TC DATETIME</strong>
          as joint work with <strong class="text-ink">ISO/TC 154/WG 5</strong>.
          Choose what you're here for — each path leads to the right view and
          deeper documentation.
        </p>
      </div>
    </section>

    <!-- Audience cards -->
    <section class="mb-16">
      <div class="section-header">
        <span class="section-number">§ 01</span>
        <h2 class="section-title">Choose your path</h2>
        <span class="section-meta">{{ audiences.length }} audiences</span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        <article
          v-for="a in audiences"
          :key="a.key"
          class="surface surface-hover p-6 flex flex-col"
        >
          <div class="flex items-baseline justify-between mb-4">
            <span class="font-mono text-xs text-accent tracking-wider">{{ a.clause }}</span>
            <span class="clause-label">{{ a.key }}</span>
          </div>
          <h3 class="font-display text-2xl text-ink mb-2 leading-tight">{{ a.title }}</h3>
          <p class="text-sm text-ink-muted leading-relaxed mb-5 flex-1">{{ a.blurb }}</p>

          <div class="flex flex-col gap-2">
            <button
              @click="emit('navigate', a.dashboardPath)"
              class="btn-ghost justify-between w-full"
            >
              <span>{{ a.dashboardLabel }}</span>
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
            </button>
            <button
              v-if="a.docSlug"
              @click="emit('navigate', `/docs/${a.docSlug}`)"
              class="font-mono text-xs uppercase tracking-wider text-accent hover:underline text-left px-3 py-2 transition-colors flex items-center justify-between"
            >
              <span>Read the full guide</span>
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
            </button>
          </div>
        </article>
      </div>
    </section>

    <!-- Concepts reference -->
    <section class="mb-16">
      <div class="section-header">
        <span class="section-number">§ 02</span>
        <h2 class="section-title">Shared concepts</h2>
      </div>
      <p class="text-ink-soft text-sm leading-relaxed mb-5 max-w-2xl">
        These documents define the vocabulary and mechanics that the
        audience-specific guides assume you understand.
      </p>
      <div class="surface divide-y divide-rule">
        <button
          v-for="c in concepts"
          :key="c.slug"
          @click="emit('navigate', `/docs/${c.slug}`)"
          class="block w-full text-left px-5 py-4 hover:bg-surface-2 transition-colors first:hover:rounded-t-sm last:hover:rounded-b-sm"
        >
          <div class="flex items-baseline justify-between gap-4">
            <span class="font-display text-xl text-ink">{{ c.title }}</span>
            <svg class="w-4 h-4 text-ink-muted shrink-0" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
          </div>
          <div class="font-mono text-xs text-ink-muted mt-1.5">{{ c.sub }}</div>
        </button>
      </div>
    </section>

    <!-- Project context -->
    <section>
      <div class="section-header">
        <span class="section-number">§ 03</span>
        <h2 class="section-title">Source &amp; canonical reference</h2>
      </div>
      <p class="text-ink-soft text-sm leading-relaxed max-w-2xl">
        Source repository:
        <a
          href="https://github.com/CalConnect/iso-8601-test-suite"
          target="_blank"
          rel="noopener"
          class="text-accent underline underline-offset-2 hover:underline-offset-4"
        >CalConnect/iso-8601-test-suite</a>.
        The full project README is the canonical reference for adapter
        protocols, YAML schemas, and CLI options.
      </p>
    </section>
  </div>
</template>
