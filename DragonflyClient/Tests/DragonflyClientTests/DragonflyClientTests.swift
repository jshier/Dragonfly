import XCTest
@testable import DragonflyClient

final class DragonflyClientTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(DragonflyClient().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
