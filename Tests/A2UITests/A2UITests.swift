import XCTest
@testable import A2UI

final class JSONValueTests: XCTestCase {
    func testDecodesScalarsAndStructures() throws {
        let json = #"{"s":"hi","n":3.14,"b":true,"z":null,"a":[1,2],"o":{"k":"v"}}"#
        let v = try JSONDecoder().decode(JSONValue.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(v["s"]?.string, "hi")
        XCTAssertEqual(v["n"]?.number, 3.14)
        XCTAssertEqual(v["b"]?.bool, true)
        XCTAssertTrue(v["z"]?.isNull == true)
        XCTAssertEqual(v["a"]?[0]?.int, 1)
        XCTAssertEqual(v["o"]?["k"]?.string, "v")
    }

    func testRoundTripsViaEncode() throws {
        let v: JSONValue = .object([
            "name": .string("Alice"),
            "age": .number(30),
            "tags": .array([.string("a"), .string("b")]),
        ])
        let data = try JSONEncoder().encode(v)
        let back = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(back, v)
    }

    func testPointerResolvesNestedPaths() throws {
        let v: JSONValue = .object([
            "user": .object([
                "profile": .object(["name": .string("Alice")]),
                "tags": .array([.string("swift"), .string("ios")]),
            ]),
        ])
        XCTAssertEqual(v.resolve(pointer: "/user/profile/name")?.string, "Alice")
        XCTAssertEqual(v.resolve(pointer: "/user/tags/1")?.string, "ios")
        XCTAssertNil(v.resolve(pointer: "/nope/nowhere"))
    }

    func testSettingCreatesIntermediateObjects() throws {
        let start: JSONValue = .object([:])
        let after = start.setting(pointer: "/a/b/c", to: .string("leaf"))
        XCTAssertEqual(after.resolve(pointer: "/a/b/c")?.string, "leaf")
    }
}

final class BindingsTests: XCTestCase {
    func testResolvesPathBindings() throws {
        let dataModel: JSONValue = .object(["reply": .object(["title": .string("Hello")])])
        let component: JSONValue = .object([
            "id": .string("card"),
            "component": .string("Card"),
            "title": .object(["path": .string("/reply/title")]),
        ])
        let resolved = Bindings.resolve(component, dataModel: dataModel)
        XCTAssertEqual(resolved["title"]?.string, "Hello")
    }

    func testResolvesNested() throws {
        let dataModel: JSONValue = .object([
            "btn": .object([
                "label": .string("Go"),
                "event": .string("user_tapped_go"),
            ]),
        ])
        let action: JSONValue = .object([
            "label": .object(["path": .string("/btn/label")]),
            "event": .object([
                "name": .object(["path": .string("/btn/event")]),
                "context": .object([:]),
            ]),
        ])
        let resolved = Bindings.resolve(action, dataModel: dataModel)
        XCTAssertEqual(resolved["label"]?.string, "Go")
        XCTAssertEqual(resolved["event"]?["name"]?.string, "user_tapped_go")
    }

    func testUnresolvedBecomesNull() throws {
        let dataModel: JSONValue = .object([:])
        let component: JSONValue = .object(["title": .object(["path": .string("/never")])])
        let resolved = Bindings.resolve(component, dataModel: dataModel)
        XCTAssertTrue(resolved["title"]?.isNull == true)
    }
}

@MainActor
final class SurfaceStateTests: XCTestCase {
    func testApplyComponents() throws {
        let s = SurfaceState(id: "main")
        s.applyComponents([
            .object(["id": .string("root"), "component": .string("Column"), "children": .array([.string("hdr")])]),
            .object(["id": .string("hdr"), "component": .string("Text"), "text": .string("Hello")]),
        ])
        XCTAssertEqual(s.component("root")?["component"]?.string, "Column")
        XCTAssertEqual(s.component("hdr")?["text"]?.string, "Hello")
    }

    func testUpdateDataModelAtRootAndPath() throws {
        let s = SurfaceState(id: "main")
        s.applyDataModel(path: "/reply/title", value: .string("Welcome"))
        XCTAssertEqual(s.dataModel.resolve(pointer: "/reply/title")?.string, "Welcome")
        s.applyDataModel(path: nil, value: .object(["cleared": .bool(true)]))
        XCTAssertEqual(s.dataModel["cleared"]?.bool, true)
        XCTAssertNil(s.dataModel.resolve(pointer: "/reply/title"))
    }
}
