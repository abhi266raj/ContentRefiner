# Architecture

`ContentRefiner` is the public SDK facade over `ContentRefinerCore`. Neither imports UI. The same portable implementation supplies models, input/output validation, ordered fallback, deadlines, cancellation, an HTTP adapter and actor-owned iterative sessions. Mac SDK adapters add typed AgentAtom ModelledSpec/AgenticOperation execution with preserved raw final JSON. Standard/source facades differ only by AgentAtom module identity.

`Packages/ContentRefinerBase` is the reusable app layer: SwiftCrossUI comparison components, observable app state, persisted provider settings, history, selected variations and original/current state. Providers are injected factories; the UI has no CLI implementation.

The Mac package supplies CLI/on-device factories. Linux and Windows use the shared HTTP factory. All three launch the same ComparisonView; only backend startup and packaging are platform specific. There is no iOS product.

Session actors commit only validated successful turns. Timeout cancels an attempt and waits for cooperative cleanup; cancellation never triggers fallback. Errors and attempts remain visible. Model instructions preserve supplied meaning/facts, but independent semantic/factual verification is a caller responsibility.
