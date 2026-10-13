# ADR-0005: App marketing version is a generation number, bumped with a commit per TestFlight upload

## Status

Accepted

## Context

The repository carries two independent version tracks:

- The WebBridgeKit framework repo has a single git tag (`v1.1.0`, 2026-05-24,
  design-system overhaul era) that predates the App Store product.
- The Drel app is versioned for App Store Connect, where marketing version
  and build number live in `project.yml` (xcodegen). The generated
  `project.pbxproj` is gitignored, so version provenance exists only in
  `project.yml` history and commit messages.

Observed history:

- 2026-08: 1.0 (builds 1–9, then 44–60) covered the first App Store
  submission and the Guideline 2.1 response.
- 2026-09-11: 1.0.1 (65) was the TestFlight patch round.
- Marketing versions 1.1, 1.2, and 1.3 never existed in `project.yml`.
- 2026-09-11: the `Drel14Release` build configuration introduced
  marketing version 1.4.0 (68) directly after 1.0.1, aligned with the
  Drel 1.4 strong-offline package generation (`Drel14Release` /
  `Drel14Store` schemes).
- Between 2026-08-19 and 2026-09-11, ~59 builds were consumed while
  `project.yml` changed only 7 times; bump commits became consistent
  only afterwards.

## Decision

- The Drel app marketing version is a **generation number** aligned with
  the container/offline-package spec generation, not a count of
  TestFlight iterations. Numbers may be skipped (1.1–1.3 are permanently
  reserved as unused).
- Build numbers are monotonic in the App Store Connect namespace and are
  never reused, regardless of marketing version.
- **Every TestFlight upload must land a `chore(build): bump <marketing>
  (<build>) — <reason> to TestFlight` commit** in the same push that
  changes `CURRENT_PROJECT_VERSION` for both the SuperApp and NSE
  `Drel14Release` configurations. The commit message is the authoritative
  build log.
- Legacy configurations keep frozen values (`1.0.1 (65)`) and are never
  bumped; `Drel14Release` / `Drel14Store` are the only store-facing
  configurations.
- Store-facing release candidates are declared with a
  `feat(drel): prepare 1.4.0 build <N> release candidate` commit; later
  feature or crash-fix builds supersede the RC and a new one must be cut.

## Consequences

### Positive

- Marketing version communicates the capability generation reviewers and
  self-hosted users see, matching the offline-package spec version.
- `git log --grep 'chore(build): bump'` reconstructs the exact
  TestFlight/upload history without App Store Connect access.
- No ambiguity between the framework tag namespace and the app release
  namespace.

### Negative

- Skipped version numbers can look accidental; this ADR and the
  submission checklists are the only records of intent.
- During gaps in bump discipline (2026-08-19 → 2026-09-11) build numbers
  are reconstructable only from `docs/release/` documents, not git.

### Neutral

- TestFlight iteration pace (occasionally many builds per day) is
  unaffected; only the recording convention is standardized.

## Alternatives Considered

### Sequential minor versions per TestFlight iteration (1.1, 1.2, 1.3, …)

Rejected. The Aug 19 round consumed 8 builds in one day; marketing
versions would be meaningless noise, and App Store versions would race
ahead of shipped releases.

### Derive app versions from the framework git tag

Rejected. The framework (`WebBridgeKit`) and the app (Drel) release on
different cadences and audiences; coupling them forces one to churn when
the other changes.

### Keep versions only in App Store Connect

Rejected. The generated pbxproj is gitignored; without a committed
version source, local builds cannot reproduce a known build number.

## References

- `docs/release/drel-v1-submission-checklist.md`
- `docs/release/drel-v1.4-submission-checklist.md`
- `docs/release/app-store-metadata.md`
- `project.yml` (`Drel14Release`, `Drel14Store` configurations)
- Commits: `e0f9066e` (bump 1.4.0 (73)), `20c54f79` (build 80 RC),
  `50b49281` (bump 1.4.0 (87)), `57ba339c` + `53d0860c` (build 88)
