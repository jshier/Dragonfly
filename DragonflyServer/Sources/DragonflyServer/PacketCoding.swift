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
//            let packet: Packet = try buffer.batchRead { inner in
//                let fixedHeader = try FixedHeader(buffer: &inner)
//                return try Packet(fixedHeader: fixedHeader, buffer: &inner)
//            }
            
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
        if buffer.readableBytes > 0 { print("Bytes available in decodeLast") }
        return .continue
    }
}

final class PacketEncoder: MessageToByteEncoder {
    typealias OutboundIn = Packet
    
    func encode(data: Packet, out: inout ByteBuffer) throws {
        out.writeBytes(data.encodable.packet.encoded)
    }
}
