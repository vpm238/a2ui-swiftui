import SwiftUI

/// Entry point for rendering an A2UI surface. Given a SurfaceState and the
/// top-level component id, recursively builds a SwiftUI view tree.
public struct A2UISurfaceView: View {
    @Environment(A2UIClient.self) var client
    public let surface: SurfaceState
    public let rootComponentId: String

    public init(surface: SurfaceState, rootComponentId: String = "root") {
        self.surface = surface
        self.rootComponentId = rootComponentId
    }

    public var body: some View {
        ComponentView(surface: surface, componentId: rootComponentId)
    }
}

/// Dispatch on component type. Resolves path bindings against the surface's
/// data model before rendering, so children see concrete values.
struct ComponentView: View {
    @Environment(A2UIClient.self) var client
    let surface: SurfaceState
    let componentId: String

    var body: some View {
        if let raw = surface.component(componentId) {
            let resolvedObj = Bindings.resolve(.object(raw), dataModel: surface.dataModel).object ?? raw
            let type = resolvedObj["component"]?.string ?? ""
            // Streaming flags — used by renderers to show typewriter carets on
            // path-bound text fields that are currently streaming (RFC
            // Proposal 2). Each is true iff the matching raw field is a
            // `{path: X}` binding AND X is the surface's active streaming path.
            let textStreaming     = streamingFlag(raw["text"])
            let headlineStreaming = streamingFlag(raw["headline"])
            let rationaleStreaming = streamingFlag(raw["rationale"])
            switch type {
            case "Column":          ColumnView(props: resolvedObj, surface: surface)
            case "Row":             RowView(props: resolvedObj, surface: surface)
            case "Text":            A2UITextView(props: resolvedObj, streamingCaret: textStreaming)
            case "Button":          A2UIButtonView(props: resolvedObj)
            case "Link":            A2UILinkView(props: resolvedObj)
            case "Card":            CardView(props: resolvedObj, surface: surface)
            case "Divider":         DividerView(props: resolvedObj)
            case "Image":           A2UIImageView(props: resolvedObj)
            case "Badge":           BadgeView(props: resolvedObj)
            case "TextField":       A2UITextFieldView(props: resolvedObj)
            case "ProgressBar":     ProgressBarView(props: resolvedObj)
            case "OptionsGrid":     OptionsGridView(props: resolvedObj)
            case "RichMessageCard": RichMessageCardView(props: resolvedObj,
                                                        headlineStreaming: headlineStreaming,
                                                        rationaleStreaming: rationaleStreaming)
            default:
                Text("[unsupported: \(type)]")
                    .foregroundStyle(.orange)
                    .font(.caption.monospaced())
            }
        } else {
            // Pending child — referenced but not yet arrived. Gray shimmer bar.
            ShimmerBar()
        }
    }

    /// True if `raw` is a single-key `{path: X}` binding AND `X` is the
    /// surface's active streaming path.
    private func streamingFlag(_ raw: JSONValue?) -> Bool {
        guard case .object(let obj) = raw,
              obj.count == 1,
              let path = obj["path"]?.string else { return false }
        return surface.isStreaming(path: path)
    }
}

// MARK: - Shimmer placeholder (Proposal 1 from the RFC)

struct ShimmerBar: View {
    @State private var phase: CGFloat = 0
    public var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        .black.opacity(0.06),
                        .black.opacity(0.14),
                        .black.opacity(0.06),
                    ],
                    startPoint: UnitPoint(x: phase - 1, y: 0.5),
                    endPoint: UnitPoint(x: phase, y: 0.5)
                )
            )
            .frame(height: 14)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

struct TextShimmer: View {
    let width: CGFloat
    init(width: CGFloat = 140) { self.width = width }
    @State private var phase: CGFloat = 0
    public var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        .black.opacity(0.06),
                        .black.opacity(0.14),
                        .black.opacity(0.06),
                    ],
                    startPoint: UnitPoint(x: phase - 1, y: 0.5),
                    endPoint: UnitPoint(x: phase, y: 0.5)
                )
            )
            .frame(width: width, height: 14)
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

/// Typewriter cursor rendered inline next to streaming text (RFC Proposal 2).
struct StreamingCaret: View {
    @State private var on: Bool = true
    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: 14)
            .opacity(on ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                    on = false
                }
            }
    }
}
