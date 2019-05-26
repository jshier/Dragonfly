//
//  Packet.swift
//  MQTTNetworking
//
//  Created by Jon Shier on 6/10/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import Foundation

public struct ControlByte {
    public enum PacketType: UInt8 {
        case connect = 0x01
        case connectAcknowledgement = 0x02
        case publish = 0x03
        case publishAcknowledgement = 0x04
        case publishReceived = 0x05
        case publishRelease = 0x06
        case publishComplete = 0x07
        case subscribe = 0x08
        case subscribeAcknowledgement = 0x09
        case unsubscribe = 0x0A
        case unsubscribeAcknowledgement = 0x0B
        case ping = 0x0C
        case pingResponse = 0x0D
    }
    
    public static let connect = ControlByte(type: .connect)
    public static func publish(firstAttempt: Bool, qos: QoS, retain: Bool) -> ControlByte {
        let dupFlag: UInt8 = (firstAttempt) ? 0b1000 : 0b0000
        let qosBits = qos.rawValue << 1
        let retainBit: UInt8 = (retain) ? 0x01 : 0x00
        
        return ControlByte(type: .publish, flags: (dupFlag | qosBits | retainBit))
    }
    public static let ping = ControlByte(type: .ping)
    public static let subscribe = ControlByte(type: .subscribe, flags: 0x02)
    
    public let type: PacketType
    public let flags: UInt8

    public init(type: PacketType, flags: UInt8 = 0) {
        self.type = type
        self.flags = flags
    }
    
    public init?(byte: UInt8) {
        guard let type = PacketType(rawValue: byte >> 4) else { return nil }
        
        self.type = type
        flags = byte & 0x0F
    }
    
    public var value: UInt8 { return UInt8(upper: type.rawValue, lower: flags) }
    public var data: Data { return Data([value]) }
}

public struct FixedHeader {
    public let controlByte: ControlByte
    public let remainingLength: UInt32
    
    public init(controlByte: ControlByte, remainingLength: UInt32) {
        self.controlByte = controlByte
        self.remainingLength = remainingLength
    }
}

public extension UInt8 {
    /// Takes the lowest 4 bits from `upper` and `lower` and combines them, `upper` at the highest, `lower` at the lowest.
    init(upper: UInt8, lower: UInt8) {
        self = (upper << 4) | (lower & 0x0F)
    }
    
    var halves: (upper: UInt8, lower: UInt8) {
        return (upper: upperBits, lower: lowerBits)
    }
    
    var upperBits: UInt8 {
        return self >> 4
    }
    
    var lowerBits: UInt8 {
        return self & 0x0F
    }
    
    var hexString: String {
        return "0x\(String(format: "%02X", self))"
    }
    
    var binaryString: String {
        let base = String(self, radix: 2)
        let padding = String(repeating: "0", count: (8 - base.count))
        
        return "0b\(padding)\(base)"
    }
}

public extension UInt16 {
    init(_ bytes: (first: UInt8, second: UInt8)) {
        self = (UInt16(bytes.first) << 8) | UInt16(bytes.second)
    }
    
    var bytes: (first: UInt8, second: UInt8) {
        return (first: UInt8(self / 256), second: UInt8(self % 256))
    }
    
    init(_ data: Data) {
        precondition(data.count >= 2)
        
        let first = data.first!
        let second = data.advanced(by: 1).first!
        
        self = .init((first: first, second: second))
    }
}

protocol Buffer {
    init(capacity: Int)
    mutating func append(_ uint8: UInt8)
    mutating func append(_ uint16: UInt16)
    mutating func append(_ string: String)
}

extension Buffer {
    mutating func append(_ uint16: UInt16) {
        let bytes = uint16.bytes
        append(bytes.first)
        append(bytes.second)
    }
}

extension Data: Buffer {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

public struct Payload {
    var data: Data
    
    init(capacity: Int = 1_024) {
        data = Data(capacity: capacity)
    }
    
    mutating func append(_ uint8: UInt8) {
        data.append(uint8)
    }
    
    mutating func append(_ uint16: UInt16) {
        data.append(uint16)
    }
    
    mutating func append(_ data: Data) {
        append(UInt16(data.count))
        self.data.append(data)
    }
    
    mutating func append(_ string: String) {
        append(UInt16(string.count))
        data.append(Data(string.utf8))
    }
    
    mutating func appendLengthEncodedData(_ data: Data) {
        var length = data.count
        repeat {
            var digit = UInt8(length % 128)
            length /= 128
            if length > 0 {
                digit |= 0x80
            }
            append(digit)
        } while length > 0
        
        self.data.append(data)
    }
}

public extension Data {
    mutating func appendEncodedLength(_ length: Int) {
        var length = length
        repeat {
            var digit = UInt8(length % 128)
            length /= 128
            if length > 0 {
                digit |= 0x80
            }
            append(digit)
        } while length > 0
    }
    
    mutating func append(_ uint16: UInt16) {
        let bytes = uint16.bytes
        append(bytes.first)
        append(bytes.second)
    }
    
    var hexDescription: String {
        return map { $0.hexString }.joined(separator: "\n")
    }
    
    var binaryDescription: String {
        return map { $0.binaryString }.joined(separator: "\n")
    }
}

public extension Bool {
    var byte: UInt8 {
        return (self) ? 0x01 : 0x00
    }
    
    init(_ byte: UInt8) {
        self = (byte & 0x01) == 0x01
    }
}

public struct VariableHeader {
    var data = Payload()
}

public struct Packet {
    public let fixedHeader: ControlByte
    public let variableHeader: VariableHeader
    public let payload: Payload
    
    public var encoded: Data {
        var packet = Data(capacity: 1_024)
        
        packet.append(fixedHeader.data)
        
        let remainingData = variableHeader.data.data + payload.data
        packet.appendEncodedLength(remainingData.count)
        packet.append(remainingData)
        
        return packet
    }
}

public protocol PacketDecodable {
    init(packet: Data) throws
}

public protocol PacketEncodable {
    var fixedHeader: ControlByte { get }
    var variableHeader: VariableHeader { get }
    var payload: Payload { get }
}

public extension PacketEncodable {
    var variableHeader: VariableHeader { return VariableHeader() }
    var payload: Payload { return Payload() }
    
    var packet: Packet {
        return Packet(fixedHeader: fixedHeader, variableHeader: variableHeader, payload: payload)
    }
}

public struct Connect {
    public enum ProtocolVersion: UInt8 {
        case v311 = 0x04
        case v50 = 0x05
    }
    
    public enum WillQoS: UInt8 {
        case zero = 0x00
        case one = 0x01
        case two = 0x02
    }
    
    public let protocolName: String
    public let protocolVersion: ProtocolVersion
    
    public let cleanSession: Bool
    public let storeWill: Bool
    public let willQoS: WillQoS
    public let retainWill: Bool
    public let keepAlive: UInt16
    public let clientID: String
    public let willTopic: String?
    public let willMessage: Data?
    public let username: String?
    public let password: String?
    
    public init(protocolName: String = "MQTT",
                protocolVersion: ProtocolVersion = .v311,
                cleanSession: Bool,
                storeWill: Bool,
                willQoS: WillQoS,
                retainWill: Bool,
                keepAlive: UInt16,
                clientID: String,
                willTopic: String?,
                willMessage: Data?,
                username: String?,
                password: String?) {
        self.protocolName = protocolName
        self.protocolVersion = protocolVersion
        self.cleanSession = cleanSession
        self.storeWill = storeWill
        self.willQoS = willQoS
        self.retainWill = retainWill
        self.keepAlive = keepAlive
        self.clientID = clientID
        self.willTopic = willTopic
        self.willMessage = willMessage
        self.username = username
        self.password = password
    }
    
    var encodedFlags: UInt8 {
        var flags: UInt8 = 0x00
        
        if cleanSession { flags |= 0b00000010 }
        if storeWill {
            flags |= 0b00000100
            flags |= (willQoS.rawValue << 3)
            flags |= (retainWill.byte << 5)
        }
        if username != nil { flags |= 0b10000000 }
        if password != nil { flags |= 0b01000000 }
        
        return flags
    }
}

extension Connect: PacketEncodable {
    public var fixedHeader: ControlByte { return .connect }
    
    public var variableHeader: VariableHeader {
        var data = Payload()
        
        data.append(protocolName)
        data.append(protocolVersion.rawValue)
        data.append(encodedFlags)
        data.append(keepAlive)
        
        return VariableHeader(data: data)
    }
    
    public var payload: Payload {
        var data = Payload()
        
        data.append(clientID)
        
        if storeWill {
            guard let willTopic = willTopic, let willMessage = willMessage else { fatalError("Will requires topic and message values") } // TODO: Replace with actual error handling or change type.
            
            data.append(willTopic)
            data.append(willMessage)
        }
        
        if let username = username {
            data.append(username)
        }
        
        if let password = password {
            data.append(password)
        }
        
        return data
    }
}

public enum ParseError: Error { case error, malformedRemainingLength }

extension Connect: PacketDecodable {
    // This will need to be from `Packet`
    public init(packet: Data) throws {
        var parsing = packet
        protocolName = try parsing.eatString()
        protocolVersion = ProtocolVersion(rawValue: parsing.eat())!
        
        let connectFlags = parsing.eat()
        
        guard (connectFlags & 0b00000001) == 0 else { throw ParseError.error } // Reserved bit isn't 0, should disconnect.
        
        cleanSession = Bool((connectFlags & 0b00000010) >> 1)
        storeWill = Bool((connectFlags & 0b00000100) >> 2)
        willQoS = (storeWill) ? WillQoS(rawValue: ((connectFlags & 0b00011000) >> 3)) ?? .zero : .zero // How to handle 3?
        retainWill = (storeWill) ? Bool((connectFlags & 0b00100000) >> 5) : false
        
        let hasUsername = Bool((connectFlags & 0b10000000) >> 7)
        let hasPassword = Bool((connectFlags & 0b01000000) >> 6)
        
        keepAlive = UInt16(parsing.eat(2))
        
        clientID = try parsing.eatString() // TODO: If empty string, fall back to generating unique id
        // TODO: If empty string and cleanSession == false, return idrejected and close connection
        if storeWill {
            willTopic = try parsing.eatString()
            let rawLength = parsing.eat(2)
            let messageLength = UInt16(rawLength)
            if messageLength > 0 {
                willMessage = Data(parsing.eat(Int(messageLength)))
            } else {
                willMessage = nil
            }
        } else {
            willTopic = nil
            willMessage = nil
        }
        
        if hasUsername {
            username = try parsing.eatString()
        } else {
            username = nil
        }
        
        if hasPassword {
            password = try parsing.eatString() // TODO: Technically this should be raw data.
        } else {
            password = nil
        }
    }
}

public struct ConnectAcknowledgement {
    public enum Response: UInt8 {
        case accepted = 0x00
        case badProtocol = 0x01
        case clientIDRejected = 0x02
        case serverUnavailable = 0x03
        case badUsernameOrPassword = 0x04
        case notAuthorized = 0x05
    }
    
    public let response: Response
    public let isSessionPresent: Bool
    
    public init(response: Response, isSessionPresent: Bool) {
        self.response = response
        self.isSessionPresent = isSessionPresent
    }
    
    init?(data: Data) {
        guard data.count == 2, let first = data.first, let second = data.last, let response = Response(rawValue: second) else { return nil }
        
        isSessionPresent = (first & 0x01) == 0x01
        self.response = response
    }
}

extension ConnectAcknowledgement: PacketEncodable {
    public var fixedHeader: ControlByte {
        return ControlByte(type: .connectAcknowledgement)
    }
    
    public var variableHeader: VariableHeader {
        var payload = Payload()
        payload.append(isSessionPresent.byte)
        payload.append(response.rawValue)
        
        return VariableHeader(data: payload)
    }
}

public struct Ping: PacketEncodable {
    public let fixedHeader: ControlByte = .ping
}

public struct PingResponse: PacketEncodable {
    public let fixedHeader: ControlByte = ControlByte(type: .pingResponse)
}

public enum QoS: UInt8 {
    case atMostOnce = 0x00
    case atLeastOnce = 0x01
    case exactlyOnce = 0x02
}

public struct Subscribe: PacketEncodable {
    public let packetID: UInt16
    public let topics: [String: QoS]
    
    public let fixedHeader: ControlByte = .subscribe
    
    public var variableHeader: VariableHeader {
        var data = Payload()
        data.append(packetID)
        
        return VariableHeader(data: data)
    }
    
    public var payload: Payload {
        var data = Payload()
        
        for (key, value) in topics {
            data.append(key)
            data.append(value.rawValue)
        }
        
        return data
    }
}

public struct SubscribeAcknowledgement {
    public enum ReturnCode: UInt8 {
        case maxQoS0 = 0x00
        case maxQoS1 = 0x01
        case maxQoS2 = 0x02
        case failure = 0x80
    }
    
    public let packetID: UInt16
    public let returnCodes: [ReturnCode]
    
    public init?(data: Data) {
        packetID = UInt16((first: data.first!, second: data.first!.advanced(by: 1)))
        let codes = data.dropFirst(2)
        returnCodes = codes.compactMap { ReturnCode(rawValue: $0) }
    }
}

public struct Publish {
    public struct Flags {
        public let firstAttempt: Bool
        public let qos: QoS
        public let shouldRetain: Bool
        
        public init(_ flags: UInt8) {
            firstAttempt = (flags & 0x08) == 0x08
            qos = QoS(rawValue: (flags & 0x06) >> 1)!
            shouldRetain = (flags & 0x01) == 0x01
        }
    }
    
    public struct Message {
        public let topic: String
        public let payload: Data
    }
    
    public let packetID: UInt16
    public let flags: Flags
    public let message: Message
    
    public init?(header: ControlByte, data: Data) {
        flags = Flags(header.flags)
        
        let lengthBytes = data.prefix(2)
        let topicLength = UInt16((first: lengthBytes[0], second: lengthBytes[1]))
        let topicBytes = data.dropFirst(2).prefix(Int(topicLength))
        let topic = String(data: topicBytes, encoding: .utf8)!
        
        let payload: Data
        if flags.qos != .atMostOnce {
            let packetIDBytes = data.dropFirst(2 + Int(topicLength)).prefix(2)
            packetID = UInt16((first: packetIDBytes[0], second: packetIDBytes[1]))
            payload = data.suffix(from: 2 + Int(topicLength) + 2)
        } else {
            packetID = 0
            payload = data.suffix(from: 2 + Int(topicLength))
        }
        
        message = Message(topic: topic, payload: payload)
    }
}

extension Collection where SubSequence == Self, Element: Equatable {
    mutating func eat(_ element: Element) -> Bool {
        guard let f = first, f == element else { return false }
        eat()
        return true
    }
    
    mutating func eat(asserting on: Element) -> Element {
        let e = eat()
        assert(on == e)
        return e
    }
    
    mutating func eat(until element: Element) -> SubSequence {
        return eat(until: { $0 == element })
    }
    
    func peek(is element: Element) -> Bool {
        if let f = self.first, f == element { return true }
        return false
    }
    
    func peek(is predicate: (_ element: Element) -> Bool) -> Bool {
        guard let f = first else { return false }
        return predicate(f)
    }
}

extension Collection where SubSequence == Self {
    @discardableResult
    mutating func eat() -> Element {
        defer { self = self.dropFirst() }
        return peek()
    }
    
    
    mutating func eat(_ n: Int) -> SubSequence {
        let (pre, rest) = self.seek(n)
        self = rest
        return pre
    }
    
    
    mutating func eat(until f: (Element) -> Bool) -> SubSequence {
        let (pre, rest) = self.seek(until: f)
        self = rest
        return pre
    }
    
    
    mutating func eat(while cond: (Element) -> Bool) -> SubSequence {
        let (result, newSelf) = seek(until: { !cond($0) })
        self = newSelf
        return result
    }
    
    mutating func eat(oneOf cond: (Element) -> Bool) -> Element? {
        guard let element = first, cond(element) else { return nil }
        self = dropFirst()
        return element
    }
    
    func peek() -> Element {
        return self.first!
    }
    
    func peek(_ n: Int) -> Element {
        assert(n > 0 && self.count >= n)
        return self.dropFirst(n).peek()
    }
    
    func seek(_ n: Int) -> (prefix: SubSequence, rest: SubSequence) {
        return (self.prefix(n), self.dropFirst(n))
    }
    
    func seek(until f: (Element) -> Bool) -> (prefix: SubSequence, rest: SubSequence) {
        guard let point = self.firstIndex(where: f) else {
            return (self[...], self[endIndex...])
        }
        return (self[..<point], self[point...])
    }
    // ... seek(until: Element), seek(through:), seek(until: Set<Element>), seek(through: Set<Element>) ...
}

public extension Data {
    mutating func eatRemainingLength() throws -> UInt32 {
        var multiplier: UInt32 = 1
        var value: UInt32 = 0
        var byte: UInt8 = 0
        repeat {
            guard multiplier <= (128 * 128 * 128) else {
                throw ParseError.malformedRemainingLength
            }
            
            byte = eat()
            value += (UInt32((byte & 127)) * multiplier)
            multiplier *= 128
        } while ((byte & 128) != 0)// && !isEmpty
        
        return value
    }
    
    mutating func eatString() throws -> String {
        let length = try eatStringLength()
        let bytes = eat(Int(length))
        
        return String(decoding: bytes, as: UTF8.self)
    }
    
    mutating func eatStringLength() throws -> UInt16 {
        let length = UInt16(eat(2))
        
        return length
    }
    
    func parseRemainingLength() throws -> (count: UInt8, length: UInt32) {
        var multiplier: UInt32 = 1
        var value: UInt32 = 0
        var byte: UInt8 = 0
        var currentIndex = startIndex
        repeat {
            guard currentIndex != endIndex else { throw RemainingLengthError.incomplete }
            
            guard multiplier <= (128 * 128 * 128) else { throw RemainingLengthError.malformed }
            
            byte = self[currentIndex]
            value += (UInt32((byte & 127)) * multiplier)
            multiplier *= 128
            currentIndex = index(after: currentIndex)
        } while ((byte & 128) != 0)// && !isEmpty
        
        return (count: UInt8(currentIndex - startIndex), length: value)
    }
}

public enum RemainingLengthError: Error {
    case malformed
    case incomplete
}
