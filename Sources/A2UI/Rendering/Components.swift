import SwiftUI

// MARK: - Column

struct ColumnView: View {
    @Environment(A2UIClient.self) var client
    let props: [String: JSONValue]
    let surface: SurfaceState

    var body: some View {
        let children = props["children"]?.array?.compactMap(\.string) ?? []
        let gap = CGFloat(props["gap"]?.number ?? 12)
        VStack(alignment: .leading, spacing: gap) {
            ForEach(children, id: \.self) { cid in
                ComponentView(surface: surface, componentId: cid)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Text

struct A2UITextView: View {
    let props: [String: JSONValue]
    /// RFC Proposal 2: true if the `text` field is bound to the currently
    /// streaming path. Renders a typewriter caret inline.
    var streamingCaret: Bool = false

    var body: some View {
        let textValue = props["text"]?.string
        let variant = props["variant"]?.string ?? "body"
        if let t = textValue, !t.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                SwiftUI.Text(t)
                    .font(fontFor(variant))
                    .foregroundStyle(colorFor(variant))
                    .fixedSize(horizontal: false, vertical: true)
                if streamingCaret {
                    StreamingCaret()
                        .frame(height: streamingCaret ? fontHeight(variant) : 0)
                }
            }
        } else {
            TextShimmer(width: variant == "h1" ? 280 : 180)
        }
    }

    private func fontHeight(_ v: String) -> CGFloat {
        switch v {
        case "h1": return 22
        case "h2": return 18
        case "caption": return 12
        default: return 16
        }
    }

    private func fontFor(_ v: String) -> Font {
        switch v {
        case "h1": return .system(size: 26, weight: .bold)
        case "h2": return .system(size: 19, weight: .semibold)
        case "caption": return .system(size: 12)
        default: return .system(size: 15)
        }
    }
    private func colorFor(_ v: String) -> Color {
        switch v {
        case "caption": return .secondary
        default: return .primary
        }
    }
}

// MARK: - Button

struct A2UIButtonView: View {
    @Environment(A2UIClient.self) var client
    let props: [String: JSONValue]

    var body: some View {
        let label = props["label"]?.string ?? ""
        let variant = props["variant"]?.string ?? "primary"
        let eventName = props["action"]?["event"]?["name"]?.string
        let eventContext = props["action"]?["event"]?["context"]?.object ?? [:]
        let ready = !label.isEmpty && eventName != nil

        Button {
            guard ready, let n = eventName else { return }
            client.sendEvent(name: n, context: eventContext, echoLabel: label)
        } label: {
            if ready {
                Text(label)
            } else {
                TextShimmer(width: 90)
            }
        }
        .buttonStyle(A2UIButtonStyle(variant: variant))
        .disabled(!ready)
    }
}

struct A2UIButtonStyle: ButtonStyle {
    let variant: String
    func makeBody(configuration: Configuration) -> some View {
        let bg: Color
        let fg: Color
        switch variant {
        case "ghost":  bg = .clear; fg = .primary
        case "danger": bg = Color(red: 0.73, green: 0.11, blue: 0.11); fg = .white
        default:       bg = .black; fg = .white
        }
        return configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                if variant == "ghost" {
                    RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08))
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

// MARK: - Card

struct CardView: View {
    let props: [String: JSONValue]
    let surface: SurfaceState

    var body: some View {
        let title = props["title"]?.string
        let childId = props["child"]?.string

        VStack(alignment: .leading, spacing: 8) {
            if let t = title, !t.isEmpty {
                SwiftUI.Text(t).font(.system(size: 18, weight: .semibold))
            }
            if let cid = childId {
                ComponentView(surface: surface, componentId: cid)
            }
        }
        .padding(16)
        .background(Color(white: 1.0))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - OptionsGrid

struct OptionsGridView: View {
    @Environment(A2UIClient.self) var client
    let props: [String: JSONValue]

    var body: some View {
        let prompt = props["prompt"]?.string ?? ""
        let options = props["options"]?.array?.compactMap(\.object) ?? []
        VStack(alignment: .leading, spacing: 8) {
            if !prompt.isEmpty {
                SwiftUI.Text(prompt)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                OptionRow(opt: opt)
            }
        }
    }
}

struct OptionRow: View {
    @Environment(A2UIClient.self) var client
    let opt: [String: JSONValue]

    var body: some View {
        let label = opt["label"]?.string ?? ""
        let rationale = opt["rationale"]?.string
        let emoji = opt["emoji"]?.string
        let eventName = opt["action"]?["event"]?["name"]?.string
        let eventContext = opt["action"]?["event"]?["context"]?.object ?? [:]

        Button {
            if let n = eventName {
                client.sendEvent(name: n, context: eventContext, echoLabel: label)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if let e = emoji { SwiftUI.Text(e).font(.system(size: 20)) }
                VStack(alignment: .leading, spacing: 2) {
                    SwiftUI.Text(label).font(.system(size: 14, weight: .semibold))
                    if let r = rationale {
                        SwiftUI.Text(r)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RichMessageCard (signature opinionated-recommendation card)

struct RichMessageCardView: View {
    @Environment(A2UIClient.self) var client
    let props: [String: JSONValue]
    /// RFC Proposal 2: streaming flags per text field. True iff that field is
    /// bound to the currently streaming path.
    var headlineStreaming: Bool = false
    var rationaleStreaming: Bool = false

    var body: some View {
        let recType = props["recommendationType"]?.string ?? "strong"
        let headline = props["headline"]?.string
        let rationale = props["rationale"]?.string
        let confidence = props["confidence"]?.string
        let accent = accentFor(recType)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: iconFor(recType))
                    .foregroundStyle(accent)
                SwiftUI.Text(tagLabelFor(recType))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(accent)
                Spacer()
                if let c = confidence {
                    SwiftUI.Text("\(c.uppercased()) CONFIDENCE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if let h = headline, !h.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    SwiftUI.Text(h)
                        .font(.system(size: 19, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    if headlineStreaming { StreamingCaret() }
                }
            } else {
                TextShimmer(width: 240)
            }
            if let r = rationale, !r.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    SwiftUI.Text(r)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    if rationaleStreaming { StreamingCaret() }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    TextShimmer(width: 360)
                    TextShimmer(width: 300)
                }
            }
            HStack(spacing: 8) {
                actionButton(props["confirmAction"], primary: true)
                actionButton(props["dismissAction"], primary: false)
            }
            .padding(.top, 6)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.12), accent.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.35))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    func actionButton(_ actionValue: JSONValue?, primary: Bool) -> some View {
        if let a = actionValue?.object {
            let label = a["label"]?.string ?? ""
            let name = a["event"]?["name"]?.string
            let ctx = a["event"]?["context"]?.object ?? [:]
            let ready = !label.isEmpty && name != nil

            Button {
                if ready, let n = name {
                    client.sendEvent(name: n, context: ctx, echoLabel: label)
                }
            } label: {
                if ready {
                    Text(label)
                } else {
                    TextShimmer(width: 110)
                }
            }
            .buttonStyle(A2UIButtonStyle(variant: primary ? "primary" : "ghost"))
            .disabled(!ready)
        }
    }

    /// recommendationType — a hint for visual treatment. The library ships six
    /// defaults; unknown types fall back to "strong". Fork these helpers to add
    /// your own domain variants.
    func accentFor(_ t: String) -> Color {
        switch t {
        case "strong":        return Color(red: 0.07, green: 0.07, blue: 0.07)  // authoritative
        case "positive":      return Color(red: 0.18, green: 0.49, blue: 0.20)  // encouraging
        case "lifestyle":     return Color(red: 0.90, green: 0.32, blue: 0.00)  // change habits
        case "informational": return Color(red: 0.08, green: 0.40, blue: 0.75)  // FYI
        case "professional":  return Color(red: 0.42, green: 0.11, blue: 0.60)  // see an expert
        case "alternative":   return Color(red: 0.68, green: 0.08, blue: 0.34)  // try instead
        default:              return .black
        }
    }
    func iconFor(_ t: String) -> String {
        switch t {
        case "strong":        return "exclamationmark.circle.fill"
        case "positive":      return "hand.thumbsup.fill"
        case "lifestyle":     return "figure.run"
        case "informational": return "info.circle.fill"
        case "professional":  return "stethoscope"
        case "alternative":   return "arrow.triangle.branch"
        default:              return "info.circle"
        }
    }
    func tagLabelFor(_ t: String) -> String {
        switch t {
        case "strong":        return "STRONG TAKE"
        case "positive":      return "POSITIVE"
        case "lifestyle":     return "LIFESTYLE"
        case "informational": return "INFO"
        case "professional":  return "PROFESSIONAL"
        case "alternative":   return "ALTERNATIVE"
        default:              return "RECOMMENDATION"
        }
    }
}
