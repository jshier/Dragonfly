import ArgumentParser
import DragonflyServer

struct Dragonfly: ParsableCommand {
    @Option(default: "127.0.0.1",
            help: "Hostname of the server.")
    var host: String
    
    @Option(name: [.customLong("logging"), .customShort("l")],
            default: false,
            help: "Whether logging is enabled.")
    var enableLogging: Bool
    
    @Option(default: 9999,
            help: "Port on which to run the server.")
    var port: Int
    
    
    func run() throws {
        DragonflyServer.run(host: host, port: port, enableLogging: enableLogging)
    }
}

Dragonfly.main()
