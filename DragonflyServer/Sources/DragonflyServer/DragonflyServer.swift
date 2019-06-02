import DragonflyCore
import NIO
import NIOExtras

public final class DragonflyServer {
    public static func run(host: String = "127.0.0.1", port: Int = 9999, enableLogging: Bool = true) {
        Logger.isEnabled = enableLogging
        
        print("🐉 Logging enabled: \(enableLogging)")
        
        let (group, bootstrap) = bootstrapServer(enableLogging: enableLogging)
        
        defer { try! group.syncShutdownGracefully() }
        
        let channel = try! bootstrap.bind(host: host, port: port).wait()
        
        guard let localAddress = channel.localAddress else {
            fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
        }
        
        print("🐉 Server started and listening on \(localAddress)")
        
        try! channel.closeFuture.wait()
        
        print("🐉 DragonflyServer closed.")
    }
    
    static func bootstrapServer(enableLogging: Bool) -> (group: MultiThreadedEventLoopGroup, bootstrap: ServerBootstrap) {
        let sharedPacketHandler = PacketHandler()
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                creatHandlers(for: channel, packetHandler: sharedPacketHandler, enableLogging: enableLogging)
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        return (group: group, bootstrap: bootstrap)
    }
    
    static func creatHandlers(for channel: Channel, packetHandler: PacketHandler, enableLogging: Bool) -> EventLoopFuture<Void> {
        var handlersNames: [(handler: ChannelHandler, name: String)]
        if enableLogging {
            handlersNames = [(handler: DebugInboundEventsHandler(), name: "InboundBytes"),
                             (handler: DebugOutboundEventsHandler(), name: "OutboundBytes"),
                             (handler: ByteToMessageHandler(PacketDecoder()), name: "PacketDecoder"),
                             (handler: DebugInboundEventsHandler(), name: "InboundPackets"),
                             (handler: MessageToByteHandler(PacketEncoder()), name: "PacketEncoder"),
                             (handler: DebugOutboundEventsHandler(), name: "OutboundPackets"),
                             (handler: packetHandler, name: "SharedPacketHandler"),
                             (handler: DebugOutboundEventsHandler(), name: "ChannelOutbound")]
        } else {
            handlersNames = [(handler: ByteToMessageHandler(PacketDecoder()), name: "PacketDecoder"),
                             (handler: MessageToByteHandler(PacketEncoder()), name: "PacketEncoder"),
                             (handler: packetHandler, name: "SharedPacketHandler")]
        }
        
        let firstHandlerName = handlersNames.removeFirst()
        var future = channel.pipeline.addHandler(firstHandlerName.handler, name: firstHandlerName.name)
        for handlerName in handlersNames {
            future = future.flatMap { channel.pipeline.addHandler(handlerName.handler, name: handlerName.name)}
        }
        
        return future
    }
}
