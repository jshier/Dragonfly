//
//  Packet.swift
//  MQTTNetworking
//
//  Created by Jon Shier on 6/10/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import Foundation

struct FixedHeader {
    enum PacketType: UInt8 {
        case connect = 0x01
        case connectionAcknowledgement = 0x02
        case publish = 0x03
        case subscribe = 0x08
        case subscribeAcknowledgement = 0x09
        case ping = 0x0C
        case pingResponse = 0x0D
    }
    
    static let connect = FixedHeader(type: .connect)
    static func publish(firstAttempt: Bool, qos: QoS, retain: Bool) -> FixedHeader {
        let dupFlag: UInt8 = (firstAttempt) ? 0b1000 : 0b0000
        let qosBits = qos.rawValue << 1
        let retainBit: UInt8 = (retain) ? 0x01 : 0x00
        
        return FixedHeader(type: .publish, flags: (dupFlag | qosBits | retainBit))
    }
    static let ping = FixedHeader(type: .ping)
    static let subscribe = FixedHeader(type: .subscribe, flags: 0x02)
    
    let type: PacketType
    let flags: UInt8

    init(type: PacketType, flags: UInt8 = 0) {
        self.type = type
        self.flags = flags
    }
    
    init?(byte: UInt8) {
        guard let type = PacketType(rawValue: byte >> 4) else { return nil }
        
        self.type = type
        flags = byte & 0x0F
    }
    
    var value: UInt8 { return UInt8(left: type.rawValue, right: flags) }
    var data: Data { var byte = value; return Data(bytes: &byte, count: 1) }
}

extension UInt8 {
    /// Takes the lowest 4 bits from `left` and `right` and combines them, `left` at the highest, `right` at the lowest.
    init(left: UInt8, right: UInt8) {
        self = (left << 4) | (right & 0x0F)
    }
}

extension UInt16 {
    init(_ bytes: (first: UInt8, second: UInt8)) {
        self = (UInt16(bytes.first) << 8) | UInt16(bytes.second)
    }
    
    var bytes: [UInt8] {
        return [UInt8(self / 256), UInt8(self % 256)]
    }
}

struct MQTTData {
    var data: Data
    
    init(capacity: Int = 1_024) {
        data = Data(capacity: capacity)
    }
    
    mutating func append(_ uint8: UInt8) {
        data.append(uint8)
    }
    
    mutating func append(_ uint16: UInt16) {
        data.append(contentsOf: uint16.bytes)
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

extension Data {
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
}

struct VariableHeader {
    var data = MQTTData()
}

struct Header {
    
}

struct Packet {
    let fixedHeader: FixedHeader
    let variableHeader: VariableHeader
    let payload: MQTTData
    
    var encoded: Data {
        var packet = Data(capacity: 1_024)
        
        packet.append(fixedHeader.data)
        
        let remainingData = variableHeader.data.data + payload.data
        packet.appendEncodedLength(remainingData.count)
        packet.append(remainingData)
        
        return packet
    }
}

protocol PacketConvertible {
    var fixedHeader: FixedHeader { get }
    var variableHeader: VariableHeader { get }
    var payload: MQTTData { get }
}

extension PacketConvertible {
    var variableHeader: VariableHeader { return VariableHeader() }
    var payload: MQTTData { return MQTTData() }
    
    var packet: Packet {
        return Packet(fixedHeader: fixedHeader, variableHeader: variableHeader, payload: payload)
    }
}

struct ConnectPacket {
    let protocolName = "MQTT"
    let protocolLevel: UInt8 = 0x04
    
    let cleanSession: Bool
    let keepAlive: UInt16
    let clientID: String
    let username: String?
    let password: String?
    
    var encodedFlags: UInt8 {
        var flags = UInt8()
        
        if cleanSession { flags |= 0x02 }
        if username != nil { flags |= 0x80 }
        if password != nil { flags |= 0x40 }
        
        return flags
    }
}

extension ConnectPacket: PacketConvertible {
    var fixedHeader: FixedHeader { return .connect }
    
    var variableHeader: VariableHeader {
        var data = MQTTData()
        
        data.append(protocolName)
        data.append(protocolLevel)
        data.append(encodedFlags)
        data.append(keepAlive)
        
        return VariableHeader(data: data)
    }
    
    var payload: MQTTData {
        var data = MQTTData()
        
        data.append(clientID)
        
        if let username = username {
            data.append(username)
        }
        
        if let password = password {
            data.append(password)
        }
        
        return data
    }
}

struct ConnectionAcknowledgementPacket {
    enum Response: UInt8 {
        case accepted = 0x00
        case badProtocol = 0x01
        case clientIDRejected = 0x02
        case serverUnavailable = 0x03
        case badUsernameOrPassword = 0x04
        case notAuthorized = 0x05
    }
    
    let response: Response
    let isSessionPresent: Bool
    
    init?(data: Data) {
        guard data.count == 2, let first = data.first, let second = data.last, let response = Response(rawValue: second) else { return nil }
        
        isSessionPresent = (first & 0x01) == 0x01
        self.response = response
    }
}

struct Ping: PacketConvertible {
    let fixedHeader: FixedHeader = .ping
}

struct PingResponse { }

enum QoS: UInt8 {
    case atMostOnce = 0x00
    case atLeastOnce = 0x01
    case exactlyOnce = 0x02
}

struct Subscribe: PacketConvertible {
    let packetID: UInt16
    let topics: [String: QoS]
    
    let fixedHeader: FixedHeader = .subscribe
    
    var variableHeader: VariableHeader {
        var data = MQTTData()
        data.append(packetID)
        
        return VariableHeader(data: data)
    }
    
    var payload: MQTTData {
        var data = MQTTData()
        
        for (key, value) in topics {
            data.append(key)
            data.append(value.rawValue)
        }
        
        return data
    }
}

struct SubscribeAcknowledgement {
    enum ReturnCode: UInt8 {
        case maxQoS0 = 0x00
        case maxQoS1 = 0x01
        case maxQoS2 = 0x02
        case failure = 0x80
    }
    
    let packetID: UInt16
    let returnCodes: [ReturnCode]
    
    init?(data: Data) {
        packetID = UInt16((first: data.first!, second: data.first!.advanced(by: 1)))
        let codes = data.dropFirst(2)
        returnCodes = codes.compactMap { ReturnCode(rawValue: $0) }
    }
}

struct Publish {
    struct Flags {
        let firstAttempt: Bool
        let qos: QoS
        let shouldRetain: Bool
        
        init(_ flags: UInt8) {
            firstAttempt = (flags & 0x08) == 0x08
            qos = QoS(rawValue: (flags & 0x06) >> 1)!
            shouldRetain = (flags & 0x01) == 0x01
        }
    }
    
    struct Message {
        let topic: String
        let payload: Data
    }
    
    let packetID: UInt16
    let flags: Flags
    let message: Message
    
    init?(header: FixedHeader, data: Data) {
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

