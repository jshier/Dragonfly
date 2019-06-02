//
//  Logger.swift
//  DragonflyServer
//
//  Created by Jon Shier on 6/1/19.
//

enum Logger {
    static var isEnabled = true
    
    
    static func log(_ string: String) {
        guard isEnabled else { return }
        
        print("🐉 \(string)")
    }
}
