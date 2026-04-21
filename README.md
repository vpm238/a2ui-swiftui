# a2ui-swiftui

**A native Swift / SwiftUI renderer for the [A2UI](https://a2ui.org/) protocol.** iOS, macOS, visionOS.

A2UI is Google's open protocol that lets AI agents describe UI declaratively; clients render it using native widgets. A2UI ships reference renderers for Flutter, Lit, Angular, and React, and the community has contributed Vue and [another SwiftUI renderer](https://github.com/sunnypurewal/a2ui-swiftui) covering the full basicCatalog.

**This renderer's focus is different:** a small, opinionated component set — including two agent-specific patterns (`OptionsGrid`, `RichMessageCard`) — built around end-to-end support for the three [progressive-rendering primitives](https://github.com/vpm238/a2ui-progressive-rendering-rfc) (pending shimmer, streaming flag, append patch op) for streaming LLM output. Pairs with [`a2ui-skills-swiftui`](https://github.com/vpm238/a2ui-skills-swiftui) for a full client-side agent.

## Install

Add to your Swift Package `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vpm238/a2ui-swiftui", from: "0.1.0"),
]
```

Then import:

```swift
import A2UI
```

## Quickstart

Point at any A2UI v0.9 server and render in SwiftUI:

```swift
import SwiftUI
import A2UI

@main
struct MyApp: App {
    @State private var client = A2UIClient(
        url: URL(string: "ws://localhost:8080/a2ui")!
    )

    var body: some Scene {
        WindowGroup {
            ChatView()
                .environment(client)
                .onAppear { client.connect() }
        }
    }
}

struct ChatView: View {
    @Environment(A2UIClient.self) var client

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(client.turns) { turn in
                // Render each turn — agent turns get A2UISurfaceView;
                // user/thinking turns render as plain bubbles.
                turnContent(turn)
            }
        }
    }

    @ViewBuilder
    func turnContent(_ turn: ChatTurn) -> some View {
        switch turn {
        case .agent(let sid):
            if let surface = client.surfaces[sid] {
                A2UISurfaceView(surface: surface, rootComponentId: "root")
            }
        case .user(let text):
            Text(text).foregroundStyle(.white).padding(10).background(.black).clipShape(RoundedRectangle(cornerRadius: 16))
        case .userPill(let label):
            Text(label).italic().padding(8).background(Color(white: 0.9)).clipShape(RoundedRectangle(cornerRadius: 16))
        case .thinking:
            ProgressView()
        }
    }
}
```

Send user actions or free text back to the agent:

```swift
client.sendText("hello")
client.sendEvent(name: "user_tapped_option", context: [:], echoLabel: "Option 1")
```

## Try it instantly — no server required

Clone and run the kitchen-sink sample, which renders every built-in component with static data:

```bash
git clone https://github.com/vpm238/a2ui-swiftui
cd a2ui-swiftui
swift run A2UIKitchenSink
```

A native window opens showing each component (Text, Button, Column, Card, OptionsGrid, RichMessageCard) with sample props. Great for verifying the library works in your environment, or for screenshots.

## Built-in components

| Component | Purpose |
|---|---|
| `Text` | Typography: `h1`, `h2`, `body`, `caption` variants |
| `Button` | Primary / ghost / danger; emits a named event on tap |
| `Column` | Vertical layout primitive; children referenced by id |
| `Card` | Titled container wrapping one child |
| `OptionsGrid` | 2–4 choice picker with label + rationale + emoji per option |
| `RichMessageCard` | Opinionated recommendation card (headline + rationale + confirm/dismiss actions). Six built-in visual variants via `recommendationType`: `strong`, `positive`, `lifestyle`, `informational`, `professional`, `alternative`. |

> `RichMessageCard` is a useful pattern whenever an agent wants to make a single, strong, opinionated recommendation — add your own variants by forking `accentFor` / `iconFor` / `tagLabelFor`.

## Architecture

```
Sources/A2UI/
├── Core/
│   ├── JSONValue.swift       — Codable dynamic JSON + JSON Pointer
│   ├── Bindings.swift        — resolves { "path": "/…" } against data model
│   ├── SurfaceState.swift    — per-surface component map + data model
│   └── A2UIClient.swift      — URLSession WebSocket + message dispatch + turns transcript
└── Rendering/
    ├── SurfaceView.swift     — A2UISurfaceView + ShimmerBar/TextShimmer (pending states)
    └── Components.swift      — SwiftUI View per component type
```

Adding your own component is straightforward: add a `case` to `ComponentView` in `SurfaceView.swift` and write a new `View`.

## Supported A2UI features

- ✅ v0.9 messages: `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`
- ✅ Path bindings (`{ "path": "/…" }`) with recursive resolution against a surface's data model
- ✅ Chat-model transcript: each agent response is a new surface appended to `turns`
- ✅ Action buttons with path-bound labels / event names — stay disabled until both resolve
- ✅ Idempotent `createSurface` (safe to re-emit for the same surface id, e.g. on server-side fallback)

### Progressive-rendering RFC ([a2ui-progressive-rendering-rfc](https://github.com/vpm238/a2ui-progressive-rendering-rfc))

This library implements all three draft proposals ahead of spec:

- ✅ **Proposal 1 — pending state:** unresolved path bindings render shimmer placeholders.
- ✅ **Proposal 2 — `streaming: true/false` flag** on `updateDataModel`: `SurfaceState` tracks `activeStreamingPath`; bound text renders a typewriter caret during streaming and drops it on finalization.
- ✅ **Proposal 3 — `append` patch op:** `SurfaceState.applyDataModel(path:op:value:streaming:)` accepts `.append`, `.prepend`, `.set`, `.remove`. String append concatenates; `A2UIClient` parses the wire-level `patch` field.

A2UI servers that emit the new `streaming` / `patch` fields work out of the box with this renderer. v0.9-only servers continue to work unchanged.

## Requirements

- Swift 6.0+
- macOS 14+, iOS 17+, visionOS 1+
- Depends only on Swift standard library + Foundation + SwiftUI (no third-party dependencies)

## License

MIT. See [LICENSE](LICENSE).

## Related

- [A2UI protocol](https://a2ui.org/) — the underlying spec
- [google/A2UI](https://github.com/google/A2UI) — upstream repo and other renderers
- [`a2ui-skills-swiftui`](https://github.com/vpm238/a2ui-skills-swiftui) — client-side skill runtime built on this renderer
- [`a2ui-starter-swiftui`](https://github.com/vpm238/a2ui-starter-swiftui) — reference app using both
- [`a2ui-progressive-rendering-rfc`](https://github.com/vpm238/a2ui-progressive-rendering-rfc) — RFC + demo for streaming UX primitives, all three implemented here
