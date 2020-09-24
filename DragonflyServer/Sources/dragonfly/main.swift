import ArgumentParser
import DragonflyServer

struct Dragonfly: ParsableCommand {
    @Option(help: "Hostname of the server.")
    var host = "127.0.0.1"
    
    @Flag(name: [.customLong("logging"), .customShort("l")],
          help: "Whether logging is enabled.")
    var enableLogging = false
    
    @Option(help: "Port on which to run the server.")
    var port = 9999
    
    func run() throws {
        DragonflyServer.run(host: host, port: port, enableLogging: enableLogging)
    }
}

Dragonfly.main()
