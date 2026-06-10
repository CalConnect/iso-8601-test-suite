# TODO.cleanup/08-enhance-about-page-and-add-developer-guide

**Status:** DONE

## Fixes applied

### 8a. About page expanded

**`site/src/views/AboutView.vue`** — Rewritten from "About Profiles" to comprehensive "About the Test Suite":
- What Is This? — explains the test suite's purpose and scope
- Data Model — OGC ModSpec terminology table with all key concepts
- Profiles — what profiles are, what they contain, registered profiles
- For Library Developers — link to developer guide
- For Standards Bodies — link to profile creation guide
- Test Approaches — brief summary with link to methodology

### 8b. Developer Guide page created

**`site/src/views/DeveloperGuideView.vue`** — New page with sections:
- Quick Start (5 minutes) — how to test a library immediately
- Adapter Interface — table of methods and which test types use them
- Parsing Modes — dedicated vs undifferentiated explanation
- JSON Protocol — request/response examples for non-Ruby implementations
- Test Types — all 6 types with descriptions
- Creating a New Profile — step-by-step for standards bodies
- Understanding Results — pass/partial/fail/not-supported meanings

**Route:** `/#/developer-guide`

### 8c. Navigation added

**`site/src/App.vue`** — Added:
- DeveloperGuideView import and route
- Nav link in Reference dropdown (desktop)
- Nav link in mobile menu
