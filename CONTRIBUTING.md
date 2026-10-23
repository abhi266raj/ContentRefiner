# Contributing

Use feature branches and PRs to main. No sibling-app edits. Keep ContentRefiner/Core UI-free and put reusable app components/state in ContentRefinerBase. Platform launchers must remain thin.

Follow AgentAtom contracts: typed spec and version, separate input/rules, injected sessions, preserved raw response, caller-owned validation/fallback. Use Swift concurrency and fail-loud errors. Source/standard facades differ only in AgentAtom import identity. Tests must inject deterministic backends; live checks are opt-in.

Run swift test, Scripts/test-release.sh, isolated product checks and the matching platform app build. Keep integration README, component versions and licenses consistent. AGPL-3.0-only; preserve dependency notices. Never commit credentials, transcripts, binaries, caches or absolute local dependency paths.
