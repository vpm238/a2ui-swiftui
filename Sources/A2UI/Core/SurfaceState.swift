import Foundation
import Observation

/// Patch operations for `applyDataModel`. Aligns with the `patch` field from
/// the A2UI progressive-rendering RFC (Proposal 3).
public enum DataPatchOp: String, Sendable {
    case set            // default v0.9 behavior: replace value at path
    case append         // string concatenation; array push
    case prepend        // string prefix; array unshift
    case remove         // delete path
}

/// Per-surface state: components keyed by id + a per-surface data model +
/// progressive-rendering metadata (which paths are currently streaming).
///
/// The client re-renders when any of these change.
@Observable
@MainActor
public final class SurfaceState {
    public let id: String
    public var catalogId: String?
    public private(set) var components: [String: [String: JSONValue]] = [:]
    public private(set) var dataModel: JSONValue = .object([:])

    /// The path of the field currently streaming — matches RFC Proposal 2's
    /// `streaming: true/false` flag. Components whose bindings point at this
    /// path can render a typewriter caret.
    public private(set) var activeStreamingPath: String?

    public init(id: String) { self.id = id }

    /// Apply a batch of components. Each must have an `id` field. Overwrites
    /// by id (A2UI v0.9 semantics: `updateComponents` replaces, not merges).
    public func applyComponents(_ incoming: [JSONValue]) {
        for c in incoming {
            guard case .object(let dict) = c, let idVal = dict["id"], let id = idVal.string else { continue }
            components[id] = dict
        }
    }

    /// Backward-compatible 2-arg shortcut — behavior identical to v0.9's
    /// `updateDataModel` wire message (set at path).
    public func applyDataModel(path: String?, value: JSONValue) {
        applyDataModel(path: path, op: .set, value: value, streaming: false)
    }

    /// Apply an `updateDataModel` message. Supports the three RFC proposals:
    /// - default `op = .set` matches v0.9.
    /// - `op = .append` concatenates to existing strings or arrays (Proposal 3).
    /// - `streaming = true` marks the path as actively streaming (Proposal 2).
    public func applyDataModel(
        path: String?,
        op: DataPatchOp = .set,
        value: JSONValue = .null,
        streaming: Bool = false
    ) {
        let resolvedPath = path ?? ""
        let isRoot = path == nil || path == "" || path == "/"

        switch op {
        case .set:
            if isRoot {
                dataModel = value
            } else {
                dataModel = dataModel.setting(pointer: resolvedPath, to: value)
            }
        case .append:
            let existing = isRoot ? dataModel : (dataModel.resolve(pointer: resolvedPath) ?? .null)
            let merged = Self.append(existing: existing, incoming: value)
            if isRoot {
                dataModel = merged
            } else {
                dataModel = dataModel.setting(pointer: resolvedPath, to: merged)
            }
        case .prepend:
            let existing = isRoot ? dataModel : (dataModel.resolve(pointer: resolvedPath) ?? .null)
            let merged = Self.append(existing: value, incoming: existing)
            if isRoot {
                dataModel = merged
            } else {
                dataModel = dataModel.setting(pointer: resolvedPath, to: merged)
            }
        case .remove:
            if !isRoot {
                dataModel = dataModel.setting(pointer: resolvedPath, to: .null)
            }
        }

        // Streaming lifecycle (Proposal 2).
        if streaming {
            activeStreamingPath = resolvedPath.isEmpty ? nil : resolvedPath
        } else if activeStreamingPath == resolvedPath {
            activeStreamingPath = nil
        }
    }

    /// Does the given path match the active streaming path? Renderers use
    /// this to show a typewriter caret on bound text fields during streaming.
    public func isStreaming(path: String) -> Bool {
        activeStreamingPath == path
    }

    public func component(_ id: String) -> [String: JSONValue]? {
        components[id]
    }

    // MARK: - Helpers

    private static func append(existing: JSONValue, incoming: JSONValue) -> JSONValue {
        switch (existing, incoming) {
        case (.string(let a), .string(let b)):
            return .string(a + b)
        case (.array(let a), let b):
            return .array(a + [b])
        case (.null, _):
            return incoming
        default:
            return incoming
        }
    }
}
