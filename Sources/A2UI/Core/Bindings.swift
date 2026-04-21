import Foundation

/// Resolve `{path: "..."}` bindings inside a JSONValue against a data model.
/// Mirrors the web client's `resolveBindings` — recurses into objects/arrays,
/// replaces any `{path: "..."}` object with the resolved value at that path.
public enum Bindings {
    public static func resolve(_ value: JSONValue, dataModel: JSONValue) -> JSONValue {
        switch value {
        case .object(let obj):
            // Single-key { "path": "..." } → look up in data model.
            if obj.count == 1, let p = obj["path"]?.string {
                return dataModel.resolve(pointer: p) ?? .null
            }
            var out: [String: JSONValue] = [:]
            for (k, v) in obj {
                out[k] = resolve(v, dataModel: dataModel)
            }
            return .object(out)
        case .array(let arr):
            return .array(arr.map { resolve($0, dataModel: dataModel) })
        default:
            return value
        }
    }
}
