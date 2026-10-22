# ContentRefiner contributor instructions

Independent Swift 6 SDK and shared desktop comparison app. Never modify sibling apps.
- `ContentRefiner` is the UI-free public SDK. `ContentRefinerCore` is its implementation.
- `Packages/ContentRefinerBase` owns shared SwiftCrossUI components, app state, settings and history. Keep maximum reusable app code here.
- Mac/Linux/Windows packages are thin launchers plus OS-specific providers and packaging. No iOS product.
- Follow AgentAtom contracts: typed ModelledSpec, stable identity/version, injected sessions, separate input/rules, preserved raw final response, explicit domain validation.
- Async/await and actors; cancellation never triggers fallback. No fabricated success or swallowed failures.
- Main is the only integration branch. Feature branches and PRs; bootstrap precedes branch protection. Never bypass protection.
- Deterministic tests inject backends. Live model checks are opt-in and reported separately.
- Standard/source SDK facades differ only in AgentAtom import identity; check Scripts/test-release.sh. Consumers choose one identity.
- SDK and platform VERSION files use stable semver. Increase only the components being released. Successful increased-version main merges publish immutable source tags and platform artifacts without modifying main.
- README begins with integration. Keep architecture, examples, changelog, licensing and releases consistent.
- AGPL-3.0-only. Preserve dependency notices. No credentials, transcripts, binaries or build caches in commits.
