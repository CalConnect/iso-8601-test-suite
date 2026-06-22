<script setup>
import { ref, watch, computed, onMounted, onUnmounted, nextTick } from "vue";
import { marked } from "marked";
import { findDoc, loadDocSource, docsByGroup } from "../content/manifest.js";

const emit = defineEmits(["navigate"]);
const props = defineProps({
  slug: { type: String, required: true },
});

const source = ref(null);
const error = ref(null);
const docEl = ref(null);

const meta = computed(() => findDoc(props.slug));
const html = computed(() => (source.value ? marked.parse(source.value) : ""));

marked.setOptions({ gfm: true, breaks: false });

async function load() {
  source.value = null;
  error.value = null;
  const md = await loadDocSource(props.slug);
  if (md == null) {
    error.value = `No doc found for slug "${props.slug}".`;
    return;
  }
  source.value = md;
  await nextTick();
}

watch(() => props.slug, load, { immediate: true });

function onClick(e) {
  const a = e.target.closest("a");
  if (!a) return;
  const href = a.getAttribute("href") || "";
  if (href.startsWith("/docs/")) {
    e.preventDefault();
    const slug = href.replace(/^\/docs\//, "").replace(/\/$/, "");
    emit("navigate", `/docs/${slug}`);
    return;
  }
  if (href.startsWith("/") && !href.startsWith("//")) {
    e.preventDefault();
    emit("navigate", href);
    return;
  }
}

onMounted(() => {
  document.addEventListener("click", onClick, true);
  window.addEventListener("popstate", scrollToTop);
});
onUnmounted(() => {
  document.removeEventListener("click", onClick, true);
  window.removeEventListener("popstate", scrollToTop);
});

function scrollToTop() {
  window.scrollTo(0, 0);
}
</script>

<template>
  <div class="max-w-[860px] mx-auto px-4 md:px-8 py-10 md:py-14">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-8 flex-wrap">
      <button @click="emit('navigate', '/')" class="clause-label hover:text-accent transition-colors">Dashboard</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <button @click="emit('navigate', '/about')" class="clause-label hover:text-accent transition-colors">About</button>
      <svg class="w-3 h-3 text-ink-faint" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>
      <span class="clause-label clause-label-accent">{{ meta ? meta.title : slug }}</span>
    </div>

    <div v-if="error" class="surface p-4 text-sm text-rust">
      {{ error }}
    </div>

    <div v-else-if="!source" class="flex items-center justify-center py-16">
      <div class="inline-block w-5 h-5 border-2 border-rule border-t-accent rounded-full animate-spin"></div>
    </div>

    <article v-else ref="docEl" class="prose-doc" v-html="html"></article>

    <!-- Footer nav -->
    <div v-if="meta" class="mt-16 pt-6 border-t border-rule">
      <div class="clause-label mb-4">More from this section</div>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <button
          v-for="d in docsByGroup[meta.group].filter((x) => x.slug !== meta.slug)"
          :key="d.slug"
          @click="emit('navigate', `/docs/${d.slug}`)"
          class="surface surface-hover text-left px-4 py-3"
        >
          <div class="font-display text-base text-ink mb-1">{{ d.title }}</div>
          <div class="text-xs text-ink-muted leading-relaxed">{{ d.summary }}</div>
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.prose-doc :deep() {
  font-family: var(--font-sans);
  font-size: 1.0625rem;
  line-height: 1.75;
  color: var(--color-ink-soft);
  word-wrap: break-word;
}
.prose-doc :deep(h1) {
  font-family: var(--font-display);
  font-weight: 500;
  font-size: 2.75rem;
  letter-spacing: -0.02em;
  line-height: 1.1;
  color: var(--color-ink);
  margin: 0 0 0.5rem;
}
.prose-doc :deep(h1)::before {
  content: "§";
  font-family: var(--font-mono);
  font-size: 0.625rem;
  font-weight: 500;
  letter-spacing: 0.14em;
  color: var(--color-accent);
  display: block;
  margin-bottom: 0.75rem;
  text-transform: uppercase;
}
.prose-doc :deep(h2) {
  font-family: var(--font-display);
  font-weight: 500;
  font-size: 1.625rem;
  letter-spacing: -0.015em;
  line-height: 1.2;
  color: var(--color-ink);
  margin: 2.5rem 0 0.875rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--color-rule);
}
.prose-doc :deep(h3) {
  font-family: var(--font-display);
  font-weight: 500;
  font-size: 1.25rem;
  letter-spacing: -0.01em;
  color: var(--color-ink);
  margin: 1.75rem 0 0.5rem;
  line-height: 1.3;
}
.prose-doc :deep(h4) {
  font-family: var(--font-sans);
  font-weight: 600;
  font-size: 1rem;
  letter-spacing: 0.02em;
  color: var(--color-ink);
  margin: 1.5rem 0 0.5rem;
}
.prose-doc :deep(p) {
  margin: 1rem 0;
}
.prose-doc :deep(a) {
  color: var(--color-accent);
  text-decoration: underline;
  text-underline-offset: 2px;
  text-decoration-thickness: 1px;
}
.prose-doc :deep(a:hover) {
  text-decoration-thickness: 2px;
}
.prose-doc :deep(strong) {
  color: var(--color-ink);
  font-weight: 600;
}
.prose-doc :deep(em) {
  font-style: italic;
  color: var(--color-ink);
}
.prose-doc :deep(ul),
.prose-doc :deep(ol) {
  margin: 1rem 0;
  padding-left: 1.5rem;
}
.prose-doc :deep(li) {
  margin: 0.375rem 0;
}
.prose-doc :deep(li::marker) {
  color: var(--color-ink-faint);
  font-family: var(--font-mono);
}
.prose-doc :deep(code) {
  font-family: var(--font-mono);
  font-size: 0.875em;
  background: var(--color-surface-2);
  color: var(--color-ink);
  padding: 0.1em 0.4em;
  border: 1px solid var(--color-rule);
  border-radius: 2px;
}
.prose-doc :deep(pre) {
  background: var(--color-surface-2);
  border: 1px solid var(--color-rule);
  border-radius: 2px;
  padding: 1rem 1.125rem;
  overflow-x: auto;
  margin: 1.125rem 0;
  font-family: var(--font-mono);
  font-size: 0.85rem;
  line-height: 1.6;
}
.prose-doc :deep(pre code) {
  background: transparent;
  border: none;
  padding: 0;
  color: var(--color-ink-soft);
  font-size: inherit;
}
.prose-doc :deep(blockquote) {
  border-left: 2px solid var(--color-accent);
  padding: 0.125rem 0 0.125rem 1.125rem;
  margin: 1.25rem 0;
  color: var(--color-ink-muted);
  font-family: var(--font-display);
  font-style: italic;
  font-size: 1.0625rem;
}
.prose-doc :deep(hr) {
  border: none;
  border-top: 1px solid var(--color-rule);
  margin: 2.25rem 0;
}
.prose-doc :deep(table) {
  width: 100%;
  border-collapse: collapse;
  margin: 1.25rem 0;
  font-size: 0.875rem;
  display: block;
  overflow-x: auto;
  font-variant-numeric: tabular-nums;
}
.prose-doc :deep(thead) {
  background: var(--color-surface-2);
}
.prose-doc :deep(th) {
  text-align: left;
  font-family: var(--font-mono);
  font-weight: 500;
  font-size: 0.75rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-ink-muted);
  padding: 0.625rem 0.875rem;
  border-bottom: 1px solid var(--color-rule);
}
.prose-doc :deep(td) {
  padding: 0.625rem 0.875rem;
  border-bottom: 1px solid var(--color-rule-soft);
  color: var(--color-ink);
  vertical-align: top;
}
.prose-doc :deep(tr:last-child td) {
  border-bottom: none;
}
</style>
