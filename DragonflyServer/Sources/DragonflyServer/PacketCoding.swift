//
//  PacketCoding.swift
//  DragonflyServer
//
//  Created by Jon Shier on 5/26/19.
//

import DragonflyCore
import Foundation
import NIO

final class PacketDecoder: ByteToMessageDecoder {
    typealias InboundOut = Packet
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        print("PacketDecoder received decode(context:buffer:)")
        print("readableBytes: \(buffer.readableBytes)")
        // Need enough bytes for the fixed header and possible remaining length.
        guard buffer.readableBytes >= 2 else { return .needMoreData }
        
        let saved = buffer
        
        do {
            let (count, remainingLength) = try buffer.getRemainingLength(at: buffer.readerIndex + 1)
            
            guard buffer.readableBytes >= (1 + Int(count) + remainingLength) else { return .needMoreData }
            
            let fixedHeader = try FixedHeader(buffer: &buffer)
            let packet = try Packet(fixedHeader: fixedHeader, buffer: &buffer)
            
            context.fireChannelRead(wrapInboundOut(packet))
            
            return .continue
        } catch {
            if (error as? RemainingLengthError) == RemainingLengthError.incomplete {
                return .needMoreData
            } else {
                buffer = saved
                throw error
            }
        }
    }
    
    func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        print("PacketDecoder received decodeLast(context:buffer:seenEOF:\(seenEOF))")
        
        if buffer.readableBytes > 0 {
            print("Bytes available in decodeLast")
            return try decode(context: context, buffer: &buffer)
        } else {
            return .continue
        }
    }
}

final class PacketEncoder: MessageToByteEncoder {
    typealias OutboundIn = PacketHandler.Outbound
    
    func encode(data: PacketHandler.Outbound, out: inout ByteBuffer) throws {
        switch data {
        case let .packet(packet): out.writeBytes(packet.encodable.packet.encoded)
        case var .preencoded(buffer): out.writeBuffer(&buffer)
        }
    }
}
