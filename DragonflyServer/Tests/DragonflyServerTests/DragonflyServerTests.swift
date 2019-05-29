import NIOTestUtils
import NIO
import XCTest
import DragonflyServer
import DragonflyCore

final class DragonflyServerTests: XCTestCase {
    func testPacketDecoder() throws {
        // Given
        let channel = EmbeddedChannel()
        var pingInput = channel.allocator.buffer(capacity: 2)
        pingInput.writeBytes([0b11000000, 0b00000000])
        let expectedInOuts = [(pingInput, [Packet.ping(.init())])]

        // When, Then
        XCTAssertNoThrow(try ByteToMessageDecoderVerifier.verifyDecoder(inputOutputPairs: expectedInOuts,
                                                                        decoderFactory: { PacketDecoder() }))
    }
    
    func testExample() {
        XCTAssertTrue(true)
    }
    
    static var allTests = [
        ("testExample", testExample),
    ]
}
