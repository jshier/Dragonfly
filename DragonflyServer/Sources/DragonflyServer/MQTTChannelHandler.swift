//
//  MQTTChannelHandler.swift
//  DragonflyServer
//
//  Created by Jon Shier on 5/23/19.
//

import Foundation
import NIO
import DragonflyCore

final class MQTTHandler: ChannelInboundHandler {
    typealias InboundIn = Packet
    typealias OutboundOut = Packet
    
}

final class PacketDecoder: ByteToMessageDecoder {
    typealias InboundOut = SomePacket
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        print("PacketDecoder received decode(context:buffer:)")
        print("readableBytes: \(buffer.readableBytes)")
        // Need enough bytes for the fixed header and possible remaining length.
        guard buffer.readableBytes >= 2 else { return .needMoreData }
        
        do {
            let (count, remainingLength) = try Data(buffer.getBytes(at: 1, length: buffer.readableBytes - 1) ?? []).parseRemainingLength()
            
            guard buffer.readableBytes >= (1 + Int(count) + Int(remainingLength)) else { return .needMoreData }
            
            guard let rawControlByte: UInt8 = buffer.readInteger(),
                let controlByte = ControlByte(byte: rawControlByte),
                let _ = buffer.readSlice(length: Int(count)),
                let rest = buffer.readSlice(length: Int(remainingLength)) else { throw ParseError.error }
            
            let fixedHeader = FixedHeader(controlByte: controlByte, remainingLength: remainingLength)
            switch fixedHeader.controlByte.type {
            case .connect:
                let connect = try Connect(packet: Data(rest.getBytes(at: 0, length: rest.readableBytes)!))
                let packet = SomePacket.connect(connect)
                context.fireChannelRead(wrapInboundOut(packet))
            default:
                // Unhandled packet, disconnect.
                context.close(promise: nil)
            }
            
            return .continue
        } catch {
            if (error as? RemainingLengthError) == RemainingLengthError.incomplete {
                return .needMoreData
            } else {
                throw error
            }
        }
    }
    
    func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        print("PacketDecoder received decodeLast(context:buffer:seenEOF:\(seenEOF))")
        if buffer.readableBytes > 0 { print("Bytes available in decodeLast") }
        return .continue
    }
}

enum SomePacket {
    case connect(Connect)
}

struct SimplePacket {
    let fixedHeader: FixedHeader
    let rest: ByteBuffer
}

extension ByteBuffer {
    var hexDescription: String {
        return getBytes(at: 0, length: readableBytes)?.map { $0.hexString }.joined(separator: "\n") ?? "No bytes."
    }
    
    var binaryDescription: String {
        return getBytes(at: 0, length: readableBytes)?.map { $0.binaryString }.joined(separator: "\n") ?? "No bytes."
    }
}

final class PacketHandler: ChannelInboundHandler {
    typealias InboundIn = SomePacket
    typealias OutboundOut = ByteBuffer
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        switch packet {
        case let .connect(connect):
            let acknowledgement = ConnectAcknowledgement(response: .notAuthorized, isSessionPresent: false)
            let data = acknowledgement.packet.encoded
            var buffer = context.channel.allocator.buffer(capacity: data.count)
            data.forEach { buffer.writeInteger($0) }
            _ = context.writeAndFlush(wrapOutboundOut(buffer)).always { _ in
                context.close(promise: nil)
            }
        }
    }
}
