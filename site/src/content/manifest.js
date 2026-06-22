export const docs = [
  {
    slug: "standards-authors",
    group: "audiences",
    title: "For standards authors",
    summary:
      "ISO/TC 154, CalConnect TC DATETIME, or anyone reviewing the standard. Use the suite to spot ambiguous normative text via cross-implementation failure clusters.",
  },
  {
    slug: "implementers",
    group: "audiences",
    title: "For implementers",
    summary:
      "You write or maintain a date/time library. Find out what your library conforms to, where it fails, and how to fix common patterns.",
  },
  {
    slug: "profile-authors",
    group: "audiences",
    title: "For profile authors",
    summary:
      "You maintain RFC 3339, W3C Datetime, EDTF, or your own subset. Learn how to formalize a profile and check its interoperability.",
  },
  {
    slug: "application-developers",
    group: "audiences",
    title: "For application developers",
    summary:
      "You're choosing a date/time library for a project. See what ISO 8601 conformance means in practice and which libraries to rely on per use case.",
  },
  {
    slug: "contributors",
    group: "audiences",
    title: "For contributors",
    summary:
      "You want to add a test, fix a bug, or write an adapter. Task index, conventions, and the path from change to merged PR.",
  },
  {
    slug: "conformance-model",
    group: "concepts",
    title: "The conformance model",
    summary:
      "Requirements, classes, profiles, declared vs. not-declared semantics, end-to-end.",
  },
  {
    slug: "test-types",
    group: "concepts",
    title: "Test types",
    summary:
      "Validity, parsing, generation, equivalence, arithmetic, round-trip — what each measures.",
  },
  {
    slug: "identifier-scheme",
    group: "concepts",
    title: "Identifier scheme",
    summary:
      "CURIE-style local IDs and RFC 5141 URN clause references.",
  },
];

const loaders = {
  "standards-authors": () => import("../content/standards-authors.md?raw"),
  implementers: () => import("../content/implementers.md?raw"),
  "profile-authors": () => import("../content/profile-authors.md?raw"),
  "application-developers": () => import("../content/application-developers.md?raw"),
  contributors: () => import("../content/contributors.md?raw"),
  "conformance-model": () => import("../content/conformance-model.md?raw"),
  "test-types": () => import("../content/test-types.md?raw"),
  "identifier-scheme": () => import("../content/identifier-scheme.md?raw"),
};

export function findDoc(slug) {
  return docs.find((d) => d.slug === slug) || null;
}

export async function loadDocSource(slug) {
  const loader = loaders[slug];
  if (!loader) return null;
  const mod = await loader();
  return mod.default;
}

export const docsByGroup = {
  audiences: docs.filter((d) => d.group === "audiences"),
  concepts: docs.filter((d) => d.group === "concepts"),
};
