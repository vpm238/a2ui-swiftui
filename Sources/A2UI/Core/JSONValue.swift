import Foundation

/// A Codable dynamic JSON value. Used throughout A2UI for component properties
/// and data-model values since wire JSON has mixed types.
public enum JSONValue: Codable, Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    // MARK: - Convenience accessors

    public var string: String? { if case .string(let s) = self { return s } else { return nil } }
    public var bool:   Bool?   { if case .bool(let b)   = self { return b } else { return nil } }
    public var number: Double? { if case .number(let n) = self { return n } else { return nil } }
    public var int:    Int?    { number.flatMap { Int(exactly: $0) } }
    public var array:  [JSONValue]?          { if case .array(let a)  = self { return a } else { return nil } }
    public var object: [String: JSONValue]?  { if case .object(let o) = self { return o } else { return nil } }
    public var isNull: Bool { if case .null = self { return true } else { return false } }

    // MARK: - Subscripts

    public subscript(key: String) -> JSONValue? {
        guard case .object(let o) = self else { return nil }
        return o[key]
    }
    public subscript(idx: Int) -> JSONValue? {
        guard case .array(let a) = self, idx >= 0, idx < a.count else { return nil }
        return a[idx]
    }

    // MARK: - JSON Pointer (RFC 6901, subset)

    /// Resolve a JSON Pointer against this value. Returns nil if any segment
    /// doesn't resolve. Array indices are decimal strings.
    public func resolve(pointer: String) -> JSONValue? {
        if pointer.isEmpty || pointer == "/" { return self }
        let trimmed = pointer.hasPrefix("/") ? String(pointer.dropFirst()) : pointer
        var cursor: JSONValue = self
        for rawPart in trimmed.split(separator: "/", omittingEmptySubsequences: false) {
            let part = String(rawPart)
                .replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
            switch cursor {
            case .object(let o):
                guard let next = o[part] else { return nil }
                cursor = next
            case .array(let a):
                guard let idx = Int(part), idx >= 0, idx < a.count else { return nil }
                cursor = a[idx]
            default:
                return nil
            }
        }
        return cursor
    }

    /// Return a new JSONValue with `value` set at the given pointer. Creates
    /// intermediate objects as needed. If pointer is empty/root, returns `value`.
    public func setting(pointer: String, to value: JSONValue) -> JSONValue {
        if pointer.isEmpty || pointer == "/" { return value }
        let trimmed = pointer.hasPrefix("/") ? String(pointer.dropFirst()) : pointer
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false).map {
            String($0).replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
        }
        return Self.setRecursive(self, parts: parts, value: value)
    }

    private static func setRecursive(_ node: JSONValue, parts: [String], value: JSONValue) -> JSONValue {
        guard let first = parts.first else { return value }
        let rest = Array(parts.dropFirst())
        var dict: [String: JSONValue]
        if case .object(let o) = node { dict = o } else { dict = [:] }
        let child = dict[first] ?? .object([:])
        dict[first] = setRecursive(child, parts: rest, value: value)
        return .object(dict)
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:       try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}
