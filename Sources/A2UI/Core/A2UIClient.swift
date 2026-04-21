import Foundation
import Observation

/// One entry in the chat transcript. Matches the web client's Turn union.
public enum ChatTurn: Identifiable, Equatable, Sendable {
    case agent(surfaceId: String)
    case user(text: String)
    case userPill(label: String)
    case thinking(id: String)

    public var id: String {
        switch self {
        case .agent(let sid):  return "a:\(sid)"
        case .user(let t):     return "u:\(t.hashValue)"
        case .userPill(let l): return "p:\(l.hashValue)"
        case .thinking(let id): return "t:\(id)"
        }
    }
}

/// A2UI v0.9 client — WebSocket transport, JSONL message framing, chat-model
/// transcript of turns. Mirrors the Lit/web client's architecture.
@Observable
@MainActor
open class A2UIClient {
    public let url: URL
    public private(set) var surfaces: [String: SurfaceState] = [:]
    public private(set) var turns: [ChatTurn] = []
    public private(set) var connected: Bool = false
    public private(set) var lastError: String?

    private var wsTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?

    public required init(url: URL) {
        self.url = url
    }

    open func connect() {
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.wsTask = task
        task.resume()
        connected = true
        lastError = nil

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    public func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        connected = false
    }

    // MARK: - Receive

    private func receiveLoop() async {
        guard let task = wsTask else { return }
        while !Task.isCancelled {
            do {
                let msg = try await task.receive()
                switch msg {
                case .string(let s):
                    onFrame(s)
                case .data(let d):
                    if let s = String(data: d, encoding: .utf8) { onFrame(s) }
                @unknown default: break
                }
            } catch {
                self.lastError = error.localizedDescription
                self.connected = false
                return
            }
        }
    }

    private func onFrame(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        let value: JSONValue
        do {
            value = try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            return
        }
        guard case .object(let top) = value else { return }

        if let payload = top["createSurface"] {
            guard let sid = payload["surfaceId"]?.string else { return }
            let state = surfaces[sid] ?? SurfaceState(id: sid)
            state.catalogId = payload["catalogId"]?.string
            surfaces[sid] = state
            attachAgentTurn(surfaceId: sid)
        } else if let payload = top["updateComponents"] {
            guard let sid = payload["surfaceId"]?.string,
                  let comps = payload["components"]?.array else { return }
            let state = surfaces[sid] ?? SurfaceState(id: sid)
            state.applyComponents(comps)
            surfaces[sid] = state
        } else if let payload = top["updateDataModel"] {
            guard let sid = payload["surfaceId"]?.string else { return }
            guard let state = surfaces[sid] else { return }
            let path = payload["path"]?.string
            let newValue = payload["value"] ?? .null
            // Progressive-rendering RFC fields — Proposal 2 (streaming flag)
            // and Proposal 3 (patch op). Backward-compatible when absent.
            let streaming = payload["streaming"]?.bool ?? false
            let opString = payload["patch"]?.string ?? "set"
            let op = DataPatchOp(rawValue: opString) ?? .set
            state.applyDataModel(path: path, op: op, value: newValue, streaming: streaming)
        } else if let payload = top["deleteSurface"] {
            if let sid = payload["surfaceId"]?.string {
                surfaces.removeValue(forKey: sid)
                turns.removeAll {
                    if case .agent(let s) = $0 { return s == sid }
                    return false
                }
            }
        }
    }

    private func attachAgentTurn(surfaceId: String) {
        // Idempotent: if this surface already has an agent turn, no-op.
        if turns.contains(where: {
            if case .agent(let s) = $0 { return s == surfaceId }
            return false
        }) { return }
        // Replace most recent thinking turn, else append.
        if let idx = turns.lastIndex(where: { if case .thinking = $0 { return true } else { return false } }) {
            turns[idx] = .agent(surfaceId: surfaceId)
        } else {
            turns.append(.agent(surfaceId: surfaceId))
        }
    }

    // MARK: - Send

    open func sendEvent(name: String, context: [String: JSONValue] = [:], echoLabel: String? = nil) {
        if let label = echoLabel {
            turns.append(.userPill(label: label))
        }
        appendThinking()
        let msg: JSONValue = .object([
            "type": .string("userAction"),
            "event": .object([
                "name": .string(name),
                "context": .object(context),
            ])
        ])
        sendJSON(msg)
    }

    open func sendText(_ text: String) {
        turns.append(.user(text: text))
        appendThinking()
        let msg: JSONValue = .object([
            "type": .string("userMessage"),
            "text": .string(text),
        ])
        sendJSON(msg)
    }

    private func appendThinking() {
        turns.append(.thinking(id: "t_\(Int(Date().timeIntervalSince1970 * 1000))"))
    }

    private func sendJSON(_ value: JSONValue) {
        guard let task = wsTask else { return }
        do {
            let data = try JSONEncoder().encode(value)
            guard let s = String(data: data, encoding: .utf8) else { return }
            Task {
                do {
                    try await task.send(.string(s))
                } catch {
                    self.lastError = error.localizedDescription
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
