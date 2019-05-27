//
//  MQTTChannelHandler.swift
//  DragonflyServer
//
//  Created by Jon Shier on 5/23/19.
//

import Foundation
import NIO
import NIOFoundationCompat
import DragonflyCore


enum Packet {
    case connect(Connect)
    case connectAcknowledgement(ConnectAcknowledgement)
    case publish(Publish)
    case publishAcknowledgement(PublishAcknowledgement)
    case subscribe(Subscribe)
    case subscribeAcknowledgement(SubscribeAcknowledgement)
    case ping(Ping)
    case pingResponse(PingResponse)
}

extension Packet {
    enum Error: Swift.Error {
        case unsupportedPacket
    }
    
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        switch fixedHeader.controlByte.type {
        case .connect: self = .connect(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .connectAcknowledgement: self = .connectAcknowledgement(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .subscribe: self = .subscribe(try .init(fixedHeader: fixedHeader, buffer: &buffer))
        case .ping: self = .ping(.init())
        case .pingResponse: self = .pingResponse(.init())
        default: throw Error.unsupportedPacket
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
        let cleanSession = Bool((connectFlags & 0b00000010) >> 1)
        let storeWill = Bool((connectFlags & 0b00000100) >> 2)
        let willQoS = (storeWill) ? try WillQoS(rawValue: ((connectFlags & 0b00011000) >> 3)).get() : .zero
        let retainWill = (storeWill) ? Bool((connectFlags & 0b00100000) >> 5) : false
        let hasUsername = Bool((connectFlags & 0b10000000) >> 7)
        let hasPassword = Bool((connectFlags & 0b01000000) >> 6)
        
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
        let isSessionPresent = Bool(try buffer.readInteger(as: UInt8.self))
        let response = try Response(rawValue: try buffer.readInteger()).get()
        
        self = .init(response: response, isSessionPresent: isSessionPresent)
    }
}

extension Subscribe {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        let packetID: UInt16 = try buffer.readInteger()
        var allSubscriptions = try buffer.readSlice(length: Int(fixedHeader.remainingLength - 2)).get()
        var subscriptions: [String: QoS] = [:]
        while allSubscriptions.readableBytes > 0 {
            let subscription = try allSubscriptions.readEncodedString()
            let qos = try QoS(rawValue: try allSubscriptions.readInteger()).get()
            subscriptions[subscription] = qos
        }
        
        self = .init(packetID: packetID, topics: subscriptions)
    }
}

extension Publish {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        let flags = Flags(fixedHeader.controlByte.flags)
        let topic = try buffer.readEncodedString()
        let packetID: UInt16 = try buffer.readInteger()
        let data = try buffer.readData(length: buffer.readableBytes).get()
        
        self = .init(flags: flags, packetID: packetID, message: .init(topic: topic, payload: data))
    }
}

extension PublishAcknowledgement {
    init(fixedHeader: FixedHeader, buffer: inout ByteBuffer) throws {
        self = .init(packetID: try buffer.readInteger())
    }
}

//extension Publish.Message {
//    init(_ buffer: inout ByteBuffer) throws {
//
//    }
//}

extension Packet {
    var encodable: PacketEncodable {
        switch self {
        case let .connect(packet): return packet
        case let .connectAcknowledgement(packet): return packet
        case let .publish(packet): return packet
        case let .publishAcknowledgement(packet): return packet
        case let .subscribe(packet): return packet
        case let .subscribeAcknowledgement(packet): return packet
        case let .ping(packet): return packet
        case let .pingResponse(packet): return packet
        }
    }
}

struct SimplePacket {
    let fixedHeader: FixedHeader
    let rest: ByteBuffer
}

final class PacketHandler: ChannelInboundHandler {
    typealias InboundIn = Packet
    typealias OutboundOut = Packet
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        switch packet {
        case let .connect(connect):
            print("Received connect from clientID: \(connect.clientID).")
            let acknowledgement = ConnectAcknowledgement(response: .accepted, isSessionPresent: false)
            context.writeAndFlush(wrapOutboundOut(.connectAcknowledgement(acknowledgement))).whenComplete { _ in
                print("Wrote ConnectAcknowledgement.")
            }
        case .connectAcknowledgement:
            print("Received .connectAcknowledgement, but server should never receive it, closing connection.")
            context.close(promise: nil)
        case let .publish(publish):
            print("Received .publish for topic: \(publish.message.topic).")
        case let .publishAcknowledgement(acknowledgement):
            print("Received .publishAcknowledgement for packetID: \(acknowledgement.packetID).")
        case let .subscribe(subscribe):
            let returnCodes = subscribe.topics.map { _ in SubscribeAcknowledgement.ReturnCode.maxQoS0 }
            let acknowledgement = SubscribeAcknowledgement(packetID: subscribe.packetID, returnCodes: returnCodes)
            context.writeAndFlush(wrapOutboundOut(.subscribeAcknowledgement(acknowledgement))).flatMap { _ ->
                EventLoopFuture<Void> in
                print("Sending publish.")
                let string = "Some message string."
                let message = Publish.Message(topic: "TOPIC", payload: Data(string.utf8))
                let publish = Publish(flags: .init(firstAttempt: true, qos: .atMostOnce, shouldRetain: true),
                                      packetID: subscribe.packetID,
                                      message: message)
                return context.writeAndFlush(self.wrapOutboundOut(.publish(publish)))
            }.whenComplete { _ in
                context.eventLoop.scheduleRepeatedAsyncTask(initialDelay: .seconds(1), delay: .seconds(1)) { (task) -> EventLoopFuture<Void> in
                    print("Sending random number.")
                    let string = "Random number: \(UInt8.random(in: UInt8.min..<UInt8.max))"
                    let message = Publish.Message(topic: "TOPIC", payload: Data(string.utf8))
                    let publish = Publish(flags: .init(firstAttempt: true, qos: .atMostOnce, shouldRetain: false),
                                          packetID: subscribe.packetID,
                                          message: message)
                    return context.writeAndFlush(self.wrapOutboundOut(.publish(publish)))
                }
            }
        case .subscribeAcknowledgement:
            print("Received .subscribeAcknowledgement, but server should never receive it, closing connection.")
            context.close(promise: nil)
        case .ping:
            context.writeAndFlush(wrapOutboundOut(.pingResponse(.init()))).whenComplete { _ in
                print("Wrote PingResponse.")
            }
        case .pingResponse:
            print("Received .pingResponse, but server should never receive it, closing connection.")
            context.close(promise: nil)
        }
    }
}
