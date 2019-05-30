import NIOTestUtils
import NIO
import XCTest
import DragonflyCore
@testable import DragonflyServer

final class DragonflyServerTests: XCTestCase {
    func testPingDecoding() {
        // Given
        let channel = EmbeddedChannel()
        var pingInput = channel.allocator.buffer(capacity: 2)
        pingInput.writeBytes([0b11000000, 0b00000000])
        let expectedInOuts = [(pingInput, [Packet.ping(.init())])]

        // When, Then
        XCTAssertNoThrow(try ByteToMessageDecoderVerifier.verifyDecoder(inputOutputPairs: expectedInOuts,
                                                                        decoderFactory: { PacketDecoder() }))
    }
    
    func testDisconnectDecoding() {
        // Given
        let channel = EmbeddedChannel()
        var disconnectInput = channel.allocator.buffer(capacity: 2)
        disconnectInput.writeBytes([0b11100000, 0b00000000])
        let expectedInOuts = [(disconnectInput, [Packet.disconnect(.init())])]
        
        // When, Then
        XCTAssertNoThrow(try ByteToMessageDecoderVerifier.verifyDecoder(inputOutputPairs: expectedInOuts,
                                                                        decoderFactory: { PacketDecoder() }))
    }
    
    func testPingThenDisconnectDecoding() {
        // Given
        let channel = EmbeddedChannel()
        var disconnectInput = channel.allocator.buffer(capacity: 4)
        disconnectInput.writeBytes([0b11000000, 0b00000000, 0b11100000, 0b00000000])
        let expectedInOuts = [(disconnectInput, [Packet.ping(.init()), Packet.disconnect(.init())])]
        
        // When, Then
        XCTAssertNoThrow(try ByteToMessageDecoderVerifier.verifyDecoder(inputOutputPairs: expectedInOuts,
                                                                        decoderFactory: { PacketDecoder() }))
    }
    
    func testConnectDecoding() {
        // Given
        let channel = EmbeddedChannel()
        var connectInput = channel.allocator.buffer(capacity: 22)
        connectInput.writeBytes([0b00010000,
                                 0b00010100,
                                 0b00000000,
                                 0b00000100,
                                 0b01001101,
                                 0b01010001,
                                 0b01010100,
                                 0b01010100,
                                 0b00000100,
                                 0b00000000,
                                 0b00000000,
                                 0b00000001,
                                 0b00000000,
                                 0b00001000,
                                 0b01100011,
                                 0b01101100,
                                 0b01101001,
                                 0b01100101,
                                 0b01101110,
                                 0b01110100,
                                 0b01001001,
                                 0b01000100])
        let connect = Connect(protocolName: "MQTT",
                              protocolVersion: .v311,
                              cleanSession: false,
                              storeWill: false,
                              willQoS: .zero,
                              retainWill: false,
                              keepAlive: 1,
                              clientID: "clientID",
                              willTopic: nil,
                              willMessage: nil,
                              username: nil,
                              password: nil)
        let expectedInOuts = [(connectInput, [Packet.connect(connect)])]
        
        // When, Then
        XCTAssertNoThrow(try ByteToMessageDecoderVerifier.verifyDecoder(inputOutputPairs: expectedInOuts,
                                                                        decoderFactory: { PacketDecoder() }))
    }

    static var allTests = [
        ("testPingDecoding", testPingDecoding),
        ("testDisconnectDecoding", testDisconnectDecoding),
        ("testConnectDecoding", testConnectDecoding),
    ]
}
