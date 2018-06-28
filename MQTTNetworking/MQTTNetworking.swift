//
//  MQTTNetworking.swift
//  MQTTNetworking
//
//  Created by Jon Shier on 6/10/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import Foundation
import Network

final class MQTT {
    static let shared = MQTT()
    
    let connection: NWConnection
    let username = "ycqitezw"
    let password = "q7101e8c0DuP"
    let queue = DispatchQueue(label: "com.jonshier.mqtt")
    let timer: DispatchSourceTimer
    
    init() {
        connection = NWConnection(host: "m12.cloudmqtt.com", port: 12_539, using: .tcp)
        timer = DispatchSource.makeTimerSource(queue: queue)
        connection.stateUpdateHandler = { [unowned self] (state) in
            self.update(for: state)
        }
        
        
        
    }
    
    deinit {
        connection.forceCancel()
    }
    
    func connect() {
        connection.start(queue: queue)
    }
    
    func update(for state: NWConnection.State) {
        switch state {
        case .preparing:
            print("Connection preparing.")
        case .setup:
            print("Connection setup.")
        case .ready:
            print("Connection ready.")
            connectUsingMQTT()
        case .waiting(let error):
            print("Connection waiting with error: \(error)")
        case .failed(let error):
            print("Connection failed with error: \(error)")
        case .cancelled:
            print("Connection cancelled.")
        default:
            fatalError()
        }
    }
    
    func connectUsingMQTT() {
        print("Sending")
        sendConnect()
        startReceiving()
    }
    
    func sendConnect() {
        let connect = ConnectPacket(cleanSession: true, keepAlive: 10, clientID: "MQTTNetwork", username: "iaflbhih", password: "sxyCRvsNG5ty")
        send(connect)
    }
    
    func subscribe() {
        let subscribe = Subscribe(packetID: 1, topics: ["/vehicle": .atMostOnce])
        send(subscribe)
    }
    
    func send<Packet: PacketConvertible>(_ packet: Packet) {
        let encoded = packet.packet.encoded
        print("Sending packet: \(encoded)")
        connection.send(content: packet.packet.encoded, completion: .contentProcessed({ (error) in
            print("Error received: \(error?.localizedDescription ?? "None")")
        }))
    }
    
    func startReceiving() {
        receiveTwoBytes { (bytes) in
            guard let header = FixedHeader(byte: bytes.first) else { fatalError() }
            
            print(header)
            
            let variableLength = bytes.second
            
            if variableLength == 0 {
                // Make reception callback
                self.processPacket(header: header, data: nil)
            } else if variableLength <= 128 {
                // Compose packet without additional variable length
                self.receiveBytes(count: Int(variableLength)) { (data, isComplete) in
                    self.processPacket(header: header, data: data)
                }
            } else {
                fatalError("Additional data too big.")
            }
        }
    }
    
    struct Value: Decodable {
        let value: Int
    }
    
    func processPacket(header: FixedHeader, data: Data?) {
        switch header.type {
        case .connectionAcknowledgement:
            packetReceived(ConnectionAcknowledgementPacket(data: data!)!)
            send(Subscribe(packetID: 1, topics: ["/vehicle": .atMostOnce]))
            timer.schedule(deadline: .now(), repeating: .seconds(5))
            timer.setEventHandler {
                self.send(Ping())
            }
            timer.resume()
        case .pingResponse: packetReceived(PingResponse())
        case .subscribeAcknowledgement: packetReceived(SubscribeAcknowledgement(data: data!)!)
        case .publish:
            let packet = Publish(header: header, data: data!)!
            let value = try! JSONDecoder().decode(Value.self, from: packet.message.payload)
            print(value)
            packetReceived(packet)
        default: fatalError("Unhandled packet type received.")
        }
    }
    
    func packetReceived<T>(_ packet: T) {
        print(packet)
        startReceiving()
    }
    
    func receiveTwoBytes(completion: @escaping (_ bytes: (first: UInt8, second: UInt8)) -> Void) {
        receiveBytes(count: 2) { (bytes, _) in completion((first: bytes.first!, second: bytes.last!)) }
    }
    
    func receiveByte(completion: @escaping (_ byte: UInt8) -> Void) {
        receiveBytes(count: 1) { (bytes, _) in completion(bytes.first!) }
    }
    
    func receiveBytes(count: Int, completion: @escaping (_ bytes: Data, _ isComplete: Bool) -> Void) {
        connection.receive(minimumIncompleteLength: count, maximumLength: count) { (data, context, isComplete, error) in
            print("Data: \(data?.description ?? "None"), context: \(String(describing: context)), isComplete: \(isComplete), error: \(error?.localizedDescription ?? "None")")
            
            guard let bytes = data else {
                if isComplete {
                    print("No data but connection complete, cancelling.")
                    self.connection.cancel()
                    return
                } else {
                    fatalError()
                }
            }
            
            completion(bytes, isComplete)
        }
    }
    
    func receiveVariableLength(completion: (_ length: Int) -> Void) {
        
    }
}
