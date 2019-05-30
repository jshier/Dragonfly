//
//  PacketParsing.swift
//  DragonflyServer
//
//  Created by Jon Shier on 5/27/19.
//

import DragonflyCore
import NIO

public enum Packet: Equatable {
    case connect(Connect)
    case connectAcknowledgement(ConnectAcknowledgement)
    case publish(Publish)
    case publishAcknowledgement(PublishAcknowledgement)
    case publishReceived(PublishReceived)
    case publishRelease(PublishRelease)
    case publishComplete(PublishComplete)
    case subscribe(Subscribe)
    case subscribeAcknowledgement(SubscribeAcknowledgement)
    case unsubscribe(Unsubscribe)
    case unsubscribeAcknowledgement(UnsubscribeAcknowledgement)
    case ping(Ping)
    case pingResponse(PingResponse)
    case disconnect(Disconnect)
}

extension Packet {
    var encodable: PacketEncodable {
        switch self {
        case let .connect(packet): return packet
        case let .connectAcknowledgement(packet): return packet
        case let .publish(packet): return packet
        case let .publishAcknowledgement(packet): return packet
        case let .publishReceived(packet): return packet
        case let .publishRelease(packet): return packet
        case let .publishComplete(packet): return packet
        case let .subscribe(packet): return packet
        case let .subscribeAcknowledgement(packet): return packet
        case let .unsubscribe(packet): return packet
        case let .unsubscribeAcknowledgement(packet): return packet
        case let .ping(packet): return packet
        case let .pingResponse(packet): return packet
        case let .disconnect(packet): return packet
        }
    }
}

extension Packet {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        switch fixedHeader.controlByte.type {
        case .connect: self = .connect(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .connectAcknowledgement: self = .connectAcknowledgement(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .publish: self = .publish(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .publishAcknowledgement: self = .publishAcknowledgement(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .publishReceived: self = .publishReceived(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .publishRelease: self = .publishRelease(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .publishComplete: self = .publishComplete(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .subscribe: self = .subscribe(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .subscribeAcknowledgement: self = .subscribeAcknowledgement(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .unsubscribe: self = .unsubscribe(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .unsubscribeAcknowledgement: self = .unsubscribeAcknowledgement(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .ping: self = .ping(.init())
        case .pingResponse: self = .pingResponse(.init())
        case .disconnect: self = .disconnect(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        }
    }
}

extension FixedHeader {
    init(buffer: inout ByteBuffer) throws {
        let controlByte = try ControlByte(try buffer.readInteger())
        let remainingLength = try buffer.readRemainingLength()
        
        self = .init(controlByte: controlByte, remainingLength: UInt32(remainingLength))
    }
}

extension Connect {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        let protocolName = try buffer.readEncodedString()
        let protocolVersion = try ProtocolVersion(rawValue: try buffer.readInteger()).get()
        
        let connectFlags: UInt8 = try buffer.readInteger()
        let cleanSession = Bool(byte: connectFlags, usingMask: 0b00000010)
        //        let cleanSession = Bool((connectFlags & 0b00000010) >> 1)
        let storeWill = Bool(byte: connectFlags, usingMask: 0b00000100)
        //        let storeWill = Bool((connectFlags & 0b00000100) >> 2)
        let willQoS = (storeWill) ? try WillQoS(rawValue: ((connectFlags & 0b00011000) >> 3)).get() : .zero
        let retainWill = (storeWill) ? Bool(byte: connectFlags, usingMask: 0b00100000) : false
        let hasPassword = Bool(byte: connectFlags, usingMask: 0b01000000)
        let hasUsername = Bool(byte: connectFlags, usingMask: 0b10000000)
        
        let keepAlive: UInt16 = try buffer.readInteger()
        // TODO: If empty string, fall back to generating unique id
        // TODO: If empty string and cleanSession == false, return idrejected and close connection
        let clientID = try buffer.readEncodedString()
        
        let willTopic: String?
        let willMessage: String?
        if storeWill {
            willTopic = try buffer.readEncodedString()
            willMessage = try buffer.readEncodedString()
        } else {
            willTopic = nil
            willMessage = nil
        }
        
        let username = (hasUsername) ? try buffer.readEncodedString() : nil
        let password = (hasPassword) ? try buffer.readEncodedString() : nil
        
        self = .init(protocolName: protocolName,
                     protocolVersion: protocolVersion,
                     cleanSession: cleanSession,
                     storeWill: storeWill,
                     willQoS: willQoS,
                     retainWill: retainWill,
                     keepAlive: keepAlive,
                     clientID: clientID,
                     willTopic: willTopic,
                     willMessage: willMessage,
                     username: username,
                     password: password)
    }
}

extension ConnectAcknowledgement {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        let isSessionPresent = Bool(try buffer.readInteger())
        let response = try Response(rawValue: try buffer.readInteger()).get()
        
        self = .init(response: response, isSessionPresent: isSessionPresent)
    }
}

extension Publish {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        let initialIndex = buffer.readerIndex
        let flags = Flags(fixedHeader.controlByte.flags)
        let topic = try buffer.readEncodedString()
        let packetID: UInt16?
        if flags.qos != .atMostOnce {
            // TODO: Rectify overload ambiguity for throwing version.
            let nonOptional: UInt16 = try buffer.readInteger()
            packetID = nonOptional
        } else {
            packetID = nil
        }
        let payloadLength = fixedHeader.remainingLength - UInt32(buffer.readerIndex - initialIndex)
        let data = try buffer.readData(length: Int(payloadLength)).get()
        
        self = .init(flags: flags, packetID: packetID, message: .init(topic: topic, payload: data))
    }
}

extension PublishAcknowledgement {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        self = .init(packetID: try buffer.readInteger())
    }
}

extension PublishReceived {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        self = .init(packetID: try buffer.readInteger())
    }
}

extension PublishRelease {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        self = .init(packetID: try buffer.readInteger())
    }
}

extension PublishComplete {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        self = .init(packetID: try buffer.readInteger())
    }
}

extension Subscribe {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        let packetID: UInt16 = try buffer.readInteger()
        var subscriptionsBuffer = try buffer.readSlice(length: Int(fixedHeader.remainingLength - 2)).get()
        var subscriptions: [String: QoS] = [:]
        while subscriptionsBuffer.readableBytes > 0 {
            let subscription = try subscriptionsBuffer.readEncodedString()
            let qos = try QoS(rawValue: try subscriptionsBuffer.readInteger()).get()
            subscriptions[subscription] = qos
        }
        
        self = .init(packetID: packetID, topics: subscriptions)
    }
}

extension SubscribeAcknowledgement {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        let packetID: UInt16 = try buffer.readInteger()
        var returnCodesBuffer = try buffer.readSlice(length: Int(fixedHeader.remainingLength - 2)).get()
        var returnCodes: [ReturnCode] = []
        while returnCodesBuffer.readableBytes > 0 {
            let returnCode = try ReturnCode(rawValue: try returnCodesBuffer.readInteger()).get()
            returnCodes.append(returnCode)
        }
        
        self = .init(packetID: packetID, returnCodes: returnCodes)
    }
}

extension Unsubscribe {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        let packetID: UInt16 = try buffer.readInteger()
        var topicsBytes = try buffer.readSlice(length: Int(fixedHeader.remainingLength - 2)).get()
        var topics: [String] = []
        while topicsBytes.readableBytes > 0 {
            topics.append(try topicsBytes.readEncodedString())
        }
        
        self = .init(packetID: packetID, topics: topics)
    }
}

extension UnsubscribeAcknowledgement {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        self = .init(packetID: try buffer.readInteger())
    }
}

extension Disconnect {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        self = .init()
    }
}
