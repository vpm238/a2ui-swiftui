import SwiftUI

// MARK: - Row (horizontal layout primitive)

struct RowView: View {
    @Environment(A2UIClient.self) var client
    let props: [String: JSONValue]
    let surface: SurfaceState

    var body: some View {
        let children = (props["children"]?.array ?? []).compactMap(\.string)
        let gap = CGFloat(props["gap"]?.number ?? 12)
        let align = props["align"]?.string ?? "center"
        let alignment: VerticalAlignment = {
            switch align {
            case "top": return .top
            case "bottom": return .bottom
            case "firstTextBaseline": return .firstTextBaseline
            default: return .center
            }
        }()
        HStack(alignment: alignment, spacing: gap) {
            ForEach(children, id: \.self) { cid in
                ComponentView(surface: surface, componentId: cid)
            }
        }
    }
}

// MARK: - Divider (visual separator)

struct DividerView: View {
    let props: [String: JSONValue]
    var body: some View {
        let orient = props["orientation"]?.string ?? "horizontal"
        if orient == "vertical" {
            Rectangle().fill(Color.black.opacity(0.08)).frame(width: 1)
        } else {
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
        }
    }
}

// MARK: - Image (async URL loading)

struct A2UIImageView: View {
    let props: [String: JSONValue]
    var body: some View {
        let urlString = props["src"]?.string ?? ""
        let alt = props["alt"]?.string ?? ""
        let cornerRadius = CGFloat(props["cornerRadius"]?.number ?? 8)
        let maxHeight = CGFloat(props["maxHeight"]?.number ?? 220)

        if let url = URL(string: urlString), !urlString.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(maxHeight: maxHeight)
                        .overlay(ProgressView())
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                case .success(let image):
                    image.resizable().scaledToFit()
                        .frame(maxHeight: maxHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                case .failure:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.red.opacity(0.08))
                        .frame(maxHeight: 60)
                        .overlay(Text("[image failed] \(alt)").font(.caption).foregroundStyle(.red))
                @unknown default: EmptyView()
                }
            }
            .accessibilityLabel(alt)
        } else {
            TextShimmer(width: 200)
        }
    }
}

// MARK: - Link (clickable text — external URL or event)

struct A2UILinkView: View {
    @Environment(A2UIClient.self) var client
    let props: [String: JSONValue]
    var body: some View {
        let label = props["label"]?.string ?? ""
        let url = props["url"]?.string
        let eventName = props["action"]?["event"]?["name"]?.string

        if let u = url.flatMap(URL.init(string:)) {
            Link(label, destination: u)
                .foregroundStyle(.blue)
                .underline()
        } else if let n = eventName {
            let ctx = props["action"]?["event"]?["context"]?.object ?? [:]
            Button {
                client.sendEvent(name: n, context: ctx, echoLabel: label)
            } label: {
                Text(label).foregroundStyle(.blue).underline()
            }
            .buttonStyle(.plain)
        } else {
            Text(label.isEmpty ? "" : label).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Badge (small colored label)

struct BadgeView: View {
    let props: [String: JSONValue]
    var body: some View {
        let label = props["label"]?.string ?? ""
        let variant = props["variant"]?.string ?? "neutral"
        let (bg, fg) = badgeColors(variant)
        Text(label.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
    private func badgeColors(_ v: String) -> (Color, Color) {
        switch v {
        case "success": return (Color.green.opacity(0.15), Color.green)
        case "warning": return (Color.orange.opacity(0.15), Color.orange)
        case "danger":  return (Color.red.opacity(0.15), Color.red)
        case "info":    return (Color.blue.opacity(0.15), Color.blue)
        default:        return (Color.black.opacity(0.08), Color.black.opacity(0.7))
        }
    }
}

// MARK: - TextField (bound input)
//
// A labeled text input. Local state mirrors what the user types; we emit the
// skill's declared event on Enter submit (or on every keystroke if
// `emitOnChange: true`). Value data-binding back to `/path` is a v0.2 item.

struct A2UITextFieldView: View {
    @Environment(A2UIClient.self) var client
    let props: [String: JSONValue]
    @State private var text: String = ""

    var body: some View {
        let label = props["label"]?.string ?? ""
        let placeholder = props["placeholder"]?.string ?? ""
        let eventName = props["action"]?["event"]?["name"]?.string ?? "text_submitted"
        let ctx = props["action"]?["event"]?["context"]?.object ?? [:]

        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(white: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onSubmit {
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    var enriched = ctx
                    enriched["value"] = .string(t)
                    client.sendEvent(name: eventName, context: enriched, echoLabel: t)
                    text = ""
                }
        }
    }
}

// MARK: - ProgressBar (0.0–1.0, optional label)

struct ProgressBarView: View {
    let props: [String: JSONValue]
    var body: some View {
        let value = max(0, min(1, props["value"]?.number ?? 0))
        let label = props["label"]?.string
        VStack(alignment: .leading, spacing: 6) {
            if let l = label, !l.isEmpty {
                HStack {
                    Text(l).font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(value * 100))%").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 6)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * CGFloat(value), height: 6)
                }
                .frame(height: 6)
            }
        }
    }
}
