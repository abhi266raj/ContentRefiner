# Releasing

Follow AgentAtom's owner-controlled main/PR workflow. Main is the only integration branch; bootstrap precedes protection. Never bypass a branch lock or force-push/delete main. Any subsequent temporary unlock needs owner authorization and must be restored.

VERSION files independently track the public SDK, shared UI Base, Mac, Linux and Windows packages. Stable semver only; decreases, leading zeroes and prerelease suffixes fail. Increase only components being released. Keep their public spec/app versions, README, CHANGELOG and release notes consistent.

A successful increased-version main merge publishes immutable source tags and matching platform executables by promoting the exact artifacts from a successful three-platform PR run. The release workflow verifies the merged source tree equals the tested PR head, requires all three successful jobs and unexpired artifacts, and publishes those tested binaries without rebuilding. Root SDK tags are plain semver for SwiftPM; component tags/releases use `ContentRefinerBase-X.Y.Z`, `ContentRefinerMac-X.Y.Z`, etc. UI subpackages are local monorepo packages; their prefixed component tags identify source/releases, not standalone root SwiftPM manifests. The SDK builds from source and pins AgentAtom's existing binary/source distributions.

Publication uses job-scoped contents-write, pushes only tags, and never changes/unlocks main. Existing tags must identify the same verified source; published releases/assets are never replaced. Fixes need a new version. Workflow dispatch validates only; unchanged versions do not release. Verify actual artifacts before announcing availability.

Mac apps embed/sign-verify AgentAtom and collect third-party notices. Linux packages require GTK 4 runtime; Windows packages include collected Swift DLLs and require the matching WinUI Windows App Runtime. Mac signing is currently ad-hoc, not notarized. Developer ID credentials belong only in CI secrets if added later.
