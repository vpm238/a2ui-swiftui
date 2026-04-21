import SwiftUI
import A2UI

/// Renders every built-in A2UI component type with sample static data so you
/// can see what the library produces without running any server.
struct KitchenSinkView: View {
    @State private var surface: SurfaceState = {
        let s = SurfaceState(id: "kitchen-sink")
        s.applyComponents(Samples.components)
        return s
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                A2UISurfaceView(surface: surface, rootComponentId: "root")
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.98))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("A2UI Kitchen Sink")
                .font(.system(size: 22, weight: .bold))
            Text("Every built-in component rendered with static sample data. Buttons log their event name to stderr.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Static sample component tree

private enum Samples {
    static var components: [JSONValue] {
        [
            // Section: Text variants
            .object([
                "id": .string("text-h1"), "component": .string("Text"),
                "text": .string("Heading 1 — the h1 variant"),
                "variant": .string("h1"),
            ]),
            .object([
                "id": .string("text-h2"), "component": .string("Text"),
                "text": .string("Heading 2 — the h2 variant"),
                "variant": .string("h2"),
            ]),
            .object([
                "id": .string("text-body"), "component": .string("Text"),
                "text": .string("Body text uses the default Text component. It renders with the system body typography and wraps on long lines so layouts stay readable."),
                "variant": .string("body"),
            ]),
            .object([
                "id": .string("text-caption"), "component": .string("Text"),
                "text": .string("Caption — for secondary labels and fine print."),
                "variant": .string("caption"),
            ]),

            // Section: Buttons
            .object([
                "id": .string("btn-primary"), "component": .string("Button"),
                "label": .string("Primary"),
                "variant": .string("primary"),
                "action": .object(["event": .object(["name": .string("demo_primary"), "context": .object([:])])]),
            ]),
            .object([
                "id": .string("btn-ghost"), "component": .string("Button"),
                "label": .string("Ghost"),
                "variant": .string("ghost"),
                "action": .object(["event": .object(["name": .string("demo_ghost"), "context": .object([:])])]),
            ]),
            .object([
                "id": .string("btn-danger"), "component": .string("Button"),
                "label": .string("Danger"),
                "variant": .string("danger"),
                "action": .object(["event": .object(["name": .string("demo_danger"), "context": .object([:])])]),
            ]),

            // Section: Card
            .object([
                "id": .string("card-child"), "component": .string("Text"),
                "text": .string("Cards wrap arbitrary children with a title + border."),
                "variant": .string("body"),
            ]),
            .object([
                "id": .string("card-demo"), "component": .string("Card"),
                "title": .string("Example Card"),
                "child": .string("card-child"),
            ]),

            // Section: OptionsGrid
            .object([
                "id": .string("options-demo"), "component": .string("OptionsGrid"),
                "prompt": .string("A typical A2UI choice — 2 to 4 options with rationales:"),
                "options": .array([
                    .object([
                        "id": .string("o1"), "label": .string("First option"),
                        "rationale": .string("A brief reason this might be the right choice."),
                        "emoji": .string("🎯"),
                        "action": .object(["event": .object(["name": .string("picked_first"), "context": .object([:])])]),
                    ]),
                    .object([
                        "id": .string("o2"), "label": .string("Second option"),
                        "rationale": .string("Why someone else might pick this instead."),
                        "emoji": .string("🧭"),
                        "action": .object(["event": .object(["name": .string("picked_second"), "context": .object([:])])]),
                    ]),
                    .object([
                        "id": .string("o3"), "label": .string("Third option"),
                        "rationale": .string("Good when neither of the first two fits."),
                        "emoji": .string("🪄"),
                        "action": .object(["event": .object(["name": .string("picked_third"), "context": .object([:])])]),
                    ]),
                ]),
            ]),

            // Section: RichMessageCard (rich opinionated recommendation)
            .object([
                "id": .string("rec-demo"), "component": .string("RichMessageCard"),
                "recommendationType": .string("professional"),
                "confidence": .string("high"),
                "headline": .string("A strong, opinionated recommendation goes here."),
                "rationale": .string("The rationale paragraph explains why — cite reasoning so the user can push back. Typically 2–3 sentences in a direct, honest voice."),
                "confirmAction": .object([
                    "label": .string("I'm in"),
                    "event": .object(["name": .string("rec_confirm"), "context": .object([:])]),
                ]),
                "dismissAction": .object([
                    "label": .string("Show alternatives"),
                    "event": .object(["name": .string("rec_dismiss"), "context": .object([:])]),
                ]),
            ]),

            // Root: Column assembling everything top-to-bottom
            .object([
                "id": .string("root"), "component": .string("Column"),
                "gap": .number(18),
                "children": .array([
                    .string("text-h1"),
                    .string("text-h2"),
                    .string("text-body"),
                    .string("text-caption"),
                    .string("btn-primary"),
                    .string("btn-ghost"),
                    .string("btn-danger"),
                    .string("card-demo"),
                    .string("options-demo"),
                    .string("rec-demo"),
                ]),
            ]),
        ]
    }
}
