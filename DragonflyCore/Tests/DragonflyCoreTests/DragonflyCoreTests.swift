import XCTest
@testable import DragonflyCore

final class DragonflyCoreTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(DragonflyCore().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
