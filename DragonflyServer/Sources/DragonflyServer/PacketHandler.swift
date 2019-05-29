//
//  PacketHandler.swift
//  DragonflyServer
//
//  Created by Jon Shier on 5/23/19.
//

import Dispatch
import DragonflyCore
import Foundation
import NIO
import NIOFoundationCompat

final class PacketHandler: ChannelInboundHandler {
    typealias InboundIn = Packet
    typealias OutboundOut = Packet
    
    private let protector = DispatchQueue(label: "server.dragonfly.handler.protected")
    // All active subscription, mapping topic to all subscribed clientIDs.
    private var subscriptions: [String: [String]] = [:]
    // clientID to Channel
    private var clientIDsToChannels: [String: Channel] = [:]
    // ObjectIdentifier(channel) to clientID
    private var channelsToClientIDs: [ObjectIdentifier: String] = [:]
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        switch packet {
        case let .connect(connect):
            handleConnect(connect, in: context)
        case .connectAcknowledgement:
            handleUnsupportedPacket(description: ".connectionAcknowledgement", in: context)
        case let .publish(publish):
            handlePublish(publish, in: context)
        case let .publishAcknowledgement(acknowledgement):
            handlePublishAcknowledgement(acknowledgement, in: context)
        case let .publishReceived(received):
            handlePublishReceived(received, in: context)
        case let .publishRelease(release):
            handlePublishRelease(release, in: context)
        case let .publishComplete(complete):
            handlePublishComplete(complete, in: context)
        case let .subscribe(subscribe):
            handleSubscribe(subscribe, in: context)
        case .subscribeAcknowledgement:
            handleUnsupportedPacket(description: ".subscribeAcknowledgement", in: context)
        case let .unsubscribe(unsubscribe):
            handleUnsubscribe(unsubscribe, in: context)
        case .unsubscribeAcknowledgement:
            handleUnsupportedPacket(description: ".unsubscribeAcknowledgement", in: context)
        case let .ping(ping):
            handlePing(ping, in: context)
        case .pingResponse:
            handleUnsupportedPacket(description: ".pingResponse", in: context)
        case let .disconnect(disconnect):
            handleDisconnect(disconnect, in: context)
        }
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        print("🐉 Channel inactive.")
        processDisconnection(in: context)
        context.fireChannelInactive()
    }
    
    // MARK: - Packet Handling
    
    func handleConnect(_ connect: Connect, in context: ChannelHandlerContext) {
        // TODO: Store all relevant properties, not just clientID
        let channel = context.channel
        print("🐉 Writing to activeChannels for clientID: \(connect.clientID)")
        protector.sync {
            self.clientIDsToChannels[connect.clientID] = channel
            self.channelsToClientIDs[ObjectIdentifier(channel)] = connect.clientID
            precondition(self.clientIDsToChannels.count == self.channelsToClientIDs.count)
        }
        let acknowledgement = ConnectAcknowledgement(response: .accepted, isSessionPresent: false)
        print("🐉 Sending ConnectAcknowledgement for clientID: \(connect.clientID)")
        context.writeAndFlush(wrapOutboundOut(.connectAcknowledgement(acknowledgement))).whenComplete { _ in
            print("🐉 Sent ConnectAcknowledgement for clientID: \(connect.clientID)")
        }
    }
    
    func handlePublish(_ publish: Publish, in context: ChannelHandlerContext) {
        print("🐉 Received .publish for topic: \(publish.message.topic).")
        let subscribers = protector.sync { self.subscriptions[publish.message.topic, default: []] }
        
        guard !subscribers.isEmpty else { return }
        
        let channels = protector.sync { subscribers.compactMap { self.clientIDsToChannels[$0] } }
        
        print("🐉 Writing publish to topic: \(publish.message.topic) to all subscribing channels.")
        channels.forEach { $0.writeAndFlush(wrapOutboundOut(.publish(publish))).whenComplete { _ in
                print("🐉 Wrote publish to topic: \(publish.message.topic).")
            }
        }
    }
    
    func handlePublishAcknowledgement(_ acknowledgement: PublishAcknowledgement, in context: ChannelHandlerContext) {
        print("🐉 Received .publishAcknowledgement for packetID: \(acknowledgement.packetID).")
    }
    
    func handlePublishReceived(_ received: PublishReceived, in context: ChannelHandlerContext) {
        print("🐉 Received .publishReceived for packetID: \(received.packetID).")
    }
    
    func handlePublishRelease(_ release: PublishRelease, in context: ChannelHandlerContext) {
        print("🐉 Received .publishRelease for packetID: \(release.packetID).")
    }
    func handlePublishComplete(_ complete: PublishComplete, in context: ChannelHandlerContext) {
        print("🐉 Received .publishComplete for packetID: \(complete.packetID).")
    }
    
    func handleSubscribe(_ subscribe: Subscribe, in context: ChannelHandlerContext) {
        let id = ObjectIdentifier(context.channel)
        let topics = subscribe.topics.keys
        
        // TODO: Produce error if not found.
        guard let clientID = protector.sync(execute: { self.channelsToClientIDs[id] }) else { return }
        
        protector.sync {
            for topic in topics {
                var subscribers = self.subscriptions[topic, default: []]
                
                if !subscribers.contains(clientID) {
                    subscribers.append(clientID)
                    self.subscriptions[topic] = subscribers
                }
            }
        }
        
        let returnCodes = topics.map { _ in SubscribeAcknowledgement.ReturnCode.maxQoS0 }
        let acknowledgement = SubscribeAcknowledgement(packetID: subscribe.packetID, returnCodes: returnCodes)
        let allTopics = topics.joined(separator: ", ")
        print("🐉 Sending SubscribeAcknowledgement for clientID: \(clientID) to topics: \(allTopics).")
        context.writeAndFlush(wrapOutboundOut(.subscribeAcknowledgement(acknowledgement))).whenComplete { _ in
            print("🐉 Sent SubscribeAcknowledgement for clientID: \(clientID) to topics: \(allTopics).")
        }
    }
    
    func handleUnsubscribe(_ unsubscribe: Unsubscribe, in context: ChannelHandlerContext) {
        let id = ObjectIdentifier(context.channel)
        let topics = unsubscribe.topics
        
        // TODO: Produce error if not found.
        guard let clientID = protector.sync(execute: { self.channelsToClientIDs[id] }) else { return }
        
        protector.sync {
            for topic in topics {
                var subscribers = self.subscriptions[topic, default: []]
                
                if let index = subscribers.firstIndex(of: clientID) {
                    subscribers.remove(at: index)
                    self.subscriptions[topic] = subscribers
                }
            }
        }
        
        let allTopics = topics.joined(separator: ", ")
        let acknowledgement = UnsubscribeAcknowledgement(packetID: unsubscribe.packetID)
        print("🐉 Sending UnsubscribeAcknowledgement for clientID: \(clientID) to topics: \(allTopics).")
        context.writeAndFlush(wrapOutboundOut(.unsubscribeAcknowledgement(acknowledgement))).whenComplete { _ in
            print("🐉 Sent UnsubscribeAcknowledgement for clientID: \(clientID) to topics: \(allTopics).")
        }
    }
    
    func handlePing(_ ping: Ping, in context: ChannelHandlerContext) {
        context.writeAndFlush(wrapOutboundOut(.pingResponse(.init()))).whenComplete { _ in
            print("🐉 Wrote PingResponse.")
        }
    }
    
    func handleDisconnect(_ disconnect: Disconnect, in context: ChannelHandlerContext) {
        print("🐉 Received .disconnect, closing connection.")
        processDisconnection(in: context)
        context.close(promise: nil)
    }
    
    func processDisconnection(in context: ChannelHandlerContext) {
        let id = ObjectIdentifier(context.channel)
        print("🐉 Processing disconnection.")
        protector.sync {
            precondition(self.channelsToClientIDs.count == self.clientIDsToChannels.count)
            self.channelsToClientIDs[id].map { (clientID) in
                self.clientIDsToChannels[clientID] = nil
                
                for (topic, var subscribers) in self.subscriptions {
                    guard let index = subscribers.firstIndex(of: clientID) else { return }
                    
                    subscribers.remove(at: index)
                    if subscribers.isEmpty {
                        self.subscriptions.removeValue(forKey: topic)
                    } else {
                        self.subscriptions[topic] = subscribers
                    }
                }
            }
            self.channelsToClientIDs[id] = nil
            precondition(self.channelsToClientIDs.count == self.clientIDsToChannels.count)
        }
    }
    
    func handleUnsupportedPacket(description: String, in context: ChannelHandlerContext) {
        print("🐉 Received \(description), but server should never receive it, closing connection.")
        context.close(promise: nil)
    }
}
