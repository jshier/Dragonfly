//
//  Extensions.swift
//  DragonflyServer
//
//  Created by Jon Shier on 5/26/19.
//

import NIO
import DragonflyCore

extension ByteBuffer {
    enum Error: Swift.Error {
        case readFailed(fromBuffer: String, ofType: String)
    }
    
//    mutating func batchRead(using closure: (_ buffer: inout ByteBuffer) throws -> Void) throws {
//        let saved = self
//        do {
//            try closure(&self)
//        } catch {
//            self = saved
//            throw error
//        }
//    }
    
    mutating func batchRead<T>(using closure: (_ buffer: inout ByteBuffer) throws -> T) rethrows -> T {
        let saved = self
        do {
            return try closure(&self)
        } catch {
            self = saved
            throw error
        }
    }
    
    mutating func readEncodedString() throws -> String {
        let saved = self
        guard let length: UInt16 = readInteger() else {
            throw Error.readFailed(fromBuffer: description, ofType: "UInt16")
        }
        
        guard let string = readString(length: Int(length)) else {
            self = saved // Roll all the way back if the readString fails.
            throw Error.readFailed(fromBuffer: description, ofType: "String of length \(length)")
        }
        
        return string
    }
    
    mutating func readInteger<T: FixedWidthInteger>(endianness: Endianness = .big, as: T.Type = T.self) throws -> T {
        guard let integer = readInteger(endianness: endianness, as: `as`) else {
            throw Error.readFailed(fromBuffer: description, ofType: "\(T.self)")
        }
        
        return integer
    }
    
    func getRemainingLength(at newReaderIndex: Int) throws -> (count: UInt8, length: Int) {
        var multiplier: UInt32 = 1
        var value: Int = 0
        var byte: UInt8 = 0
        var currentIndex = newReaderIndex
        repeat {
            guard currentIndex != (readableBytes + 1) else { throw RemainingLengthError.incomplete }
            
            guard multiplier <= (128 * 128 * 128) else { throw RemainingLengthError.malformed }
            
            guard let nextByte: UInt8 = getInteger(at: currentIndex) else { throw RemainingLengthError.incomplete }
            
            byte = nextByte
            
            value += Int(UInt32(byte & 127) * multiplier)
            multiplier *= 128
            currentIndex += 1
        } while ((byte & 128) != 0)// && !isEmpty
        
        return (count: UInt8(currentIndex - newReaderIndex), length: value)
    }
    
    mutating func readRemainingLength() throws -> Int {
        let (count, length) = try getRemainingLength(at: readerIndex)
        moveReaderIndex(forwardBy: Int(count))
        
        return length
    }
    
    var hexDescription: String {
        return getBytes(at: 0, length: readableBytes)?.map { $0.hexString }.joined(separator: "\n") ?? "No bytes."
    }
    
    var binaryDescription: String {
        return getBytes(at: 0, length: readableBytes)?.map { $0.binaryString }.joined(separator: "\n") ?? "No bytes."
    }
}
