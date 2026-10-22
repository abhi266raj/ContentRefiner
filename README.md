<img src="Assets/ContentRefiner.png" width="96" alt="Content Refiner logo">

# ContentRefiner

A UI-free Swift SDK for refining any text, plus **one shared SwiftCrossUI comparison app** released for Mac, Linux and Windows.

[Releases](https://github.com/abhi266raj/ContentRefiner/releases) · [Packages](Packages/README.md) · [Architecture](docs/architecture.md) · [Contributing](CONTRIBUTING.md)

## Integrate the SDK

Add the repository in Xcode or Swift Package Manager at exact version **0.1.0**:

```swift
.package(url: "https://github.com/abhi266raj/ContentRefiner.git", exact: "0.1.0")
```

Add the UI-free product to your target:

```swift
.product(name: "ContentRefiner", package: "ContentRefiner")
```

The SDK does not depend on SwiftCrossUI or any app package. It owns input/output models, validation, ordered fallback, deadlines, cancellation, variations and iterative sessions.

### Refine any content with ordered fallback

```swift
import ContentRefiner

let primary = HTTPRefinementBackend(
    id: "primary",
    endpoint: URL(string: "http://localhost:11434/v1/chat/completions")!,
    model: "your-installed-model"
)
let secondary = HTTPRefinementBackend(
    id: "secondary",
    endpoint: URL(string: "http://localhost:1234/v1/chat/completions")!,
    model: "your-other-model"
)
let client = RefinementClient(
    backends: [primary, secondary],
    configuration: .init(timeoutSeconds: 90, fallbackEnabled: true)
)
let result = try await client.refine(.init(
    originalContent: "We are writing to ask if you could send the report soon.",
    userInstruction: "Make this email concise and polite.",
    contentKind: "email"
))
print(result.output.variations[0].content)
print(result.providerID)
// result.attempts explains every provider attempt.
// result.rawResponse preserves the final model JSON.
```

HTTP endpoints must implement the chat-completions message format and JSON-object response mode. No model server is installed by the SDK. Pass authorization through the backend's `headers:` parameter when needed; never put credentials in source. Fallback sends the same content to each enabled backend, in order.

### Keep an immutable original across rounds

```swift
let session = try RefinementSession(
    originalContent: "Your article, code, email, prompt or document",
    client: client
)
try await session.refine("Improve clarity", variationCount: 2)
try await session.selectVariation(2)
try await session.refine("Strengthen the opening")
try await session.refine("") // Reuses consolidated guidance after a successful turn.
let snapshot = await session.snapshot
print(snapshot.latestContent)
// snapshot.originalContent stays unchanged; snapshot.turns preserves successful history.
```

Use `instructionOverride:` for edited consolidated guidance. Optional `contentKind`, `correctionFocus` and `knownIssues` customize refinement without screenplay-specific constraints. Metadata is requested in English; content keeps its language unless the user requests a change. These are model instructions, not an independent factual-verification or translation service.

Failure/cancellation preserves the previous draft. Concurrent turns fail explicitly. Output validation rejects empty content, missing/duplicate indexes and incorrect variation counts before accepting a result or trying fallback. Backends must honor cancellation so an expired attempt can clean up before the next begins.

### AgentAtom integration on Mac

`ContentRefinerSpec` conforms to `AgentAtom.ModelledSpec`, with typed `Input`/`Output`, identity `ContentRefiner`, and spec version `0.1.0`. Input JSON remains separate from rules; the injected session is executed with `AgenticOperation`.

```swift
import AgentAtom
import ContentRefiner

@available(macOS 26, *)
func onDeviceClient() -> RefinementClient {
    let backend = AgentAtomRefinementBackend(id: "apple", strictSchema: false) {
        guard let session = AppleIntelligenceSession() else {
            throw ContentRefinerError.unavailable("On-device model unavailable")
        }
        return session
    }
    return RefinementClient(backends: [backend])
}
```

Inject any AgentAtom session, or conform any service to `RefinementBackend` to use your own API or deterministic test fixture. The optional Mac adapters integrate installed Codex, Claude, Antigravity and Grok CLIs via TerminalAgentSession. CLI sign-in/credentials stay with each CLI; those tools are not bundled or downloaded.

### Products and module identities

| Product | Purpose |
| --- | --- |
| `ContentRefiner` | Public SDK; Mac AgentAtom integration uses its pinned binary dependency |
| `ContentRefinerSource` | Same SDK with AgentAtomSource types on Mac |
| `ContentRefinerCore` | Portable Foundation implementation, no UI or AgentAtom dependency |
| `ContentRefinerCommand` / `content-refiner` | Optional portable command interface |

ContentRefiner itself builds from source. On Mac, select one AgentAtom identity per consumer: the standard SDK pairs with AgentAtom; the source SDK pairs with AgentAtomSource. Linux/Windows build the same generic engine/HTTP API without the Apple-specific AgentAtom adapter. The SDK requires Swift 6; its Mac deployment target is 15.

## One comparison app, three platform packages

```text
ContentRefiner                 UI-free public SDK
└── ContentRefinerCore         Models, engine, sessions, fallback, HTTP

ContentRefinerBase             Shared SwiftCrossUI components and app model
├── ContentRefinerMac          Thin AppKit launcher + local Mac providers
├── ContentRefinerLinux        Thin GTK launcher
└── ContentRefinerWindows      Thin WinUI launcher
```

All comparison views, provider settings/order, history, original/current handling, variation selection and refinement controls live in **ContentRefinerBase**. Platform packages do not duplicate the UI. Each component has its own `VERSION`; GitHub releases provide separate platform executables. No iPhone/iOS app is included.

Download the matching artifact from [Releases](https://github.com/abhi266raj/ContentRefiner/releases). Or clone/build:

```sh
git clone https://github.com/abhi266raj/ContentRefiner.git
cd ContentRefiner
Scripts/build-app.sh                          # Mac .app, ZIP and DMG
open dist/ContentRefiner.app
# On Linux, with Swift and GTK 4 development packages:
Scripts/build-portable.sh Linux
# On Windows, in a Swift/Visual Studio developer PowerShell:
Scripts/build-windows.ps1
```

Paste/open UTF-8 text, enter a directive, then refine. Original content stays scrollable; the full revised content expands alongside it. Refine again, choose variations, edit consolidated instructions, inspect changes/attempts, and select/copy or export text. Settings saves provider order, fallback enablement, model/path/endpoint overrides and timeout. Linux/Windows use configured HTTP endpoints; Mac additionally offers CLI and on-device providers.

Mac app: macOS 26+; Apple Intelligence additionally needs supported hardware and a ready model. Linux app: desktop session and GTK 4 runtime. Windows app: matching Windows App Runtime for SwiftCrossUI's WinUI backend (see [platform instructions](Packages/README.md)). Mac release apps are ad-hoc signed, not notarized. The SDK remains independent of these GUI requirements.

## Validate

```sh
swift test
Scripts/test-release.sh
Scripts/verify-products.sh
swift run content-refiner --help
Scripts/build-app.sh
```

CI builds/tests the SDK and shared app on Mac, Linux and Windows. Tests inject deterministic backends; live model checks are opt-in and reported separately. Version-increasing main merges publish immutable component tags/artifacts; unchanged versions validate only. See [RELEASING.md](RELEASING.md).

## License

AGPL-3.0-only. Inspired by ScriptRefiner and Script Chat's editing principles, without importing Script Maker or private agent packages. SwiftCrossUI and other dependencies retain their own licenses; see [LICENSE](LICENSE), [COPYRIGHT](COPYRIGHT), and [notices](THIRD_PARTY_NOTICES.md).
