# Delivery plan — bilingual visual documentation

Feature: [oui#1](https://github.com/atilla777/oui/issues/1).
Inputs: [requirements R1](spec.md#requirements-r1) and [technical design D1](design.md).
This document describes work boundaries/dependencies, not implementation progress.
Actual statuses and assignees belong to GitHub Issues. No RIS/Beads installation
or Slyx work item is required.

## Why four implementation units

One task would combine site engineering, a substantial native visual-content
collection, bilingual technical authoring and external hosting delivery. These
have separate observable results and environments. Four units let a verified
vertical sample establish the shared contract, then allow catalogue/media and
usage-guide authoring in parallel. Checks remain part of each result, not a
separate test-only work item. Native dependency failure need not stop prose work.

## T1 — Bilingual site and one real vertical sample

**Outcome:** From a fresh oui checkout a reader can build/preview EN/RU pages,
change language without losing the logical page, search/filter the sample and
inspect one genuine native screenshot with keyboard-operable controls.

**Boundary:** Implement the `site/` skeleton, stable locked Node/VitePress tooling,
shared components, page/data/media contracts in D1, local search, no-JS fallback,
and one completely authored `layout` capability in both languages. Capture the
sample through approved ISD and retain review/cleanup evidence. Describe explicit
sample validation versus final full-coverage validation. Add maintainer commands
and reusable tests. Do not create 18 empty pages presented as completed content.

**Checks:** AC-001/002/004/009/012, sample portions of AC-005/008/010.
Build/preview under `/oui/`; EN/RU page/anchor switching, localized search and
no-results/reset, viewer keyboard/focus, 360/1280 layout, no-JS content, schema
negative fixtures and genuine media provenance. No API or native behavior changes.

**Prerequisites:** None in this feature. Before graphics verify native resources
and an approved full ISD copy; stop/report a real environment blocker, never bypass.
This is the first executable unit after preparation and fresh state checks.

## T2 — Complete visual catalogue and Integration Lab overview

**Outcome:** A browser-only reader can see and understand every current gallery
capability and all four Lab screens in English and Russian.

**Boundary:** Fill D1 contracts with all 19 gallery IDs and four Lab IDs; reuse the
T1 layout sample instead of counting it twice. Each entry includes actual images,
supported behavior, limitations, packages, code links and native launch command.
Capture both languages when the rendered text differs; record justified neutral
reuse explicitly. Add relevant alternate states, notably focus, modality and
viewport changes. Optional short motion recordings must not delay image coverage.

**Checks:** AC-003/005/008; full-data AC-004/009/010; AC-012 preservation.
Strict source-ID coverage, all asset/provenance/digest checks, individual visual
and privacy review, EN/RU parity and browser filtering/viewer scenarios.
Inspect modal and wide/narrow states, not only the default palette.

**Prerequisites:** T1's checked page/data/media/component contracts. Native captures
may be explored earlier but final contributions must consume the shared contracts.
No partial gallery qualifies as completion of this issue.

## T3 — Bilingual getting started, package map and four recipes

**Outcome:** A reader can connect an exact oui revision, choose a minimal package
set, run a native example and follow menu/settings/HUD/inventory integration paths.

**Boundary:** EN/RU acquisition/build/resource guide, narrow dependency map,
ownership/lifecycle and experimental limits; four practical recipes linked to the
real consumers and restricted fixtures. Use existing contracts as authoritative
sources. Add complete compile fixtures for executable snippets and verify native
commands with safe graphical runs as needed. No API rewriting or duplicate engine.

**Checks:** AC-006/007 plus affected AC-002/009/010/012.
Compile documented runnable examples with required collection/link flags, verify
resource paths and commands, check factual package/dependency claims and language
parity. Scope snippet checks separately from ordinary static-site build.

**Prerequisites:** T1's route/localization/content conventions. Independent of T2:
recipe text can link stable Lab/capability routes and existing native references;
final media/link integration is checked by T4.

## T4 — Integrated checked site and GitHub Pages delivery

**Outcome:** The reviewed complete bilingual site is maintainable, automatically
checked, and reachable at its verified Pages URL.

**Boundary:** Integrate T2/T3 on one exact revision; enforce strict coverage and
negative checks in CI, document content/media update, verify licenses/privacy,
prepare least-privilege PR check and main/manual Pages workflows, enable/verify
hosting under applicable authorization, and add the verified entry link in oui's
README. Do not update Slyx or publish a new library tag/release.

**Checks:** AC-010/011/012 and integrated AC-001 through AC-009.
Build/parity/media/link/snippet/browser evidence must apply to the common revision.
Rehearse updating a page and media record; inspect workflow permissions and external
links/notices. After delivery test fresh HTTP nested EN/RU routes, assets, language
switching and search. A Pages setting/permission failure leaves delivery blocked;
report the valid build separately, without closing the feature as complete.

**Prerequisites:** T2 and T3 complete and checked. Native execution environment for
snippet/command checks must be available separately from the static build runner.

## Dependency and coverage check

Directed dependencies (dependent → prerequisite): T2 → T1; T3 → T1;
T4 → T2; T4 → T3. No cycle. Only T1 has no feature-local prerequisites.

All R1 criteria have an owning task and a final combined check in T4. T1 and T2
share AC-004/009/010 by intentionally testing sample then full dataset, not duplicate
ownership. A task being open does not prove that its environment or inputs are ready.
Do not begin implementation as part of this preparation operation.

## Continuation

Read feature issue #1 and its child issues for current IDs/status, then the linked
exact R1/D1 document revision. Start T1 only after checking the task has not already
been claimed/completed and preparing an own safe worktree. Later tasks preserve the
same feature IDs/contracts and report substantive scope conflicts before changing
them. Preparation does not itself deploy Pages or certify native qualifications.
