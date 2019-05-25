import XCTest
@testable import DragonflyCore

final class DragonflyCoreTests: XCTestCase {
    func testOneByteRemainingLengthParsing() throws {
        // Given
        let bytes: [UInt8] = [0x0F]
        var data = Data(bytes)
        
        // When
        let length = try data.eatRemainingLength()
        
        // Then
        XCTAssertEqual(length, 15)
        XCTAssertTrue(data.isEmpty)
    }
    
    func testTwoByteRemainingLengthParsing() throws {
        // Given
        let bytes: [UInt8] = [0xC1, 0x02]
        var data = Data(bytes)
        
        // When
        let length = try data.eatRemainingLength()
        
        // Then
        XCTAssertEqual(length, 321)
        XCTAssertTrue(data.isEmpty)
    }
    
    func testThreeByteRemainingLengthParsing() throws {
        // Given
        let bytes: [UInt8] = [0x8D, 0x99, 0x03]
        var data = Data(bytes)
        
        // When
        let length = try data.eatRemainingLength()
        
        // Then
        XCTAssertEqual(length, 52_365)
        XCTAssertTrue(data.isEmpty)
    }
    
    func testFourByteRemainingLengthParsing() throws {
        // Given
        let bytes: [UInt8] = [0x80, 0x80, 0x80, 0x01]
        var data = Data(bytes)

        
        // When
        let length = try data.eatRemainingLength()
        
        // Then
        XCTAssertEqual(length, 2_097_152)
        XCTAssertTrue(data.isEmpty)
    }
    
    func testInvalidRemainingLengthParsing() throws {
        // Given
        let bytes: [UInt8] = [0xFF, 0xFF, 0xFF, 0x80]
        var data = Data(bytes)
        
        // When, Then
        XCTAssertThrowsError(try data.eatRemainingLength())
    }
    
    func testStringParsing() throws {
        // Given
        // From MQTT standard.
        let bytes: [UInt8] = [0b00000000, 0b00000100, 0b01001101, 0b01010001, 0b01010100, 0b01010100]
        var data = Data(bytes)
        
        // When
        let string = try data.eatString()
        
        // Then
        XCTAssertEqual(string, "MQTT")
    }
    
    func testThatEmptyStringParses() throws {
        // Given
        let bytes: [UInt8] = [0b00000000, 0b00000000]
        var data = Data(bytes)
        
        // When
        let string = try data.eatString()
        
        // Then
        XCTAssertEqual(string, "")
    }
    
    func testThatConnectPacketCanBeDecoded() throws {
        // Given
        let clientID = "TestID"
        let connect = Connect(cleanSession: false,
                              storeWill: false,
                              willQoS: .zero,
                              retainWill: false,
                              keepAlive: 5,
                              clientID: clientID,
                              willTopic: nil,
                              willMessage: nil,
                              username: nil,
                              password: nil)
        
        // When
        let data = connect.packet.encoded[2...]
        let parsed = try Connect(packet: data)
        
        // Then
        XCTAssertEqual(connect.cleanSession, parsed.cleanSession)
        XCTAssertEqual(connect.keepAlive, parsed.keepAlive)
        XCTAssertEqual(parsed.clientID, clientID)
    }

    static var allTests = [
        ("testOneByteVariableLengthParsing", testOneByteRemainingLengthParsing),
        ("testTwoByteVariableLengthParsing", testTwoByteRemainingLengthParsing),
        ("testThreeByteVariableLengthParsing", testThreeByteRemainingLengthParsing),
        ("testFourByteVariableLengthParsing", testFourByteRemainingLengthParsing),
        ("testInvalidRemainingLengthParsing", testInvalidRemainingLengthParsing),
        ("testStringParsing", testStringParsing),
    ]
}
