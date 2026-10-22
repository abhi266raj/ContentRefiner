# Package layout and app integration

- Root `ContentRefiner`: reusable SDK without UI; published semantic tags work with remote SwiftPM consumers.
- `ContentRefinerBase`: reusable SwiftCrossUI `ComparisonView`, original/refined panes, toolbar, history/settings panels and observable `RefinerAppModel`. Most app code belongs here.
- `ContentRefinerMac`: thin launcher and Mac-specific CLI/Apple Intelligence adapters.
- `ContentRefinerLinux` / `ContentRefinerWindows`: thin launchers using shared HTTP provider settings and UI.
- `ContentRefinerCommand`: optional portable command interface around the SDK engine.

The platform app packages and shared UI package use relative dependencies within this monorepo. To reuse the UI, clone the repo and add `Packages/ContentRefinerBase` as a local package, then import `ContentRefinerBase` and place `ComparisonView(model:)` inside a SwiftCrossUI window. Supply your own `RefinerProviderOption` factories when embedding it. Generic SDK consumers need only the root package URL; they never resolve GUI dependencies.

## Mac

Swift 6 and macOS 26+. Run `Scripts/build-app.sh`; the ZIP/DMG includes the app, AgentAtom framework and third-party notices. No sibling source checkout is required. Apps are ad-hoc signed; Developer ID signing/notarization is not configured.

## Linux

Swift 6.4.1 and GTK 4 development libraries for compilation (`libgtk-4-dev` on Ubuntu 24.04). Run `Scripts/build-portable.sh Linux`. End users need a desktop session and GTK 4 runtime (`libgtk-4-1`). Configure your chat-completions endpoint/model in Settings.

## Windows

Use Swift 6.4.1 and a Visual Studio developer environment. Run `Scripts/build-windows.ps1`. The ZIP contains the executable and collected Swift runtime DLLs. SwiftCrossUI's WinUI backend also requires the matching Windows App Runtime specified by its pinned swift-winui dependency. See its [SDK/runtime requirements](https://github.com/moreSwift/swift-winui#sdk-versions). Install the vendor's matching runtime when required; the app does not silently install it.

All platforms build the same comparison components. File-open/save dialogs and text selection are supplied by SwiftCrossUI's platform backend. Provider settings are local and contain no stored API key; HTTP authorization may be supplied through CONTENT_REFINER_API_KEY in the process environment.
