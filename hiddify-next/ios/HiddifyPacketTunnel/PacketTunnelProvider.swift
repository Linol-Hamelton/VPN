//
//  PacketTunnelProvider.swift
//  SingBoxPacketTunnel
//
//  Created by GFWFighter on 7/24/1402 AP.
//

import NetworkExtension

class PacketTunnelProvider: ExtensionProvider {

    private var upload: Int64 = 0
    private var download: Int64 = 0
    // private var trafficLock: NSLock = NSLock()
    
    // var trafficReader: TrafficReader!
    
    override func startTunnel(options: [String : NSObject]?) async throws {
        try await super.startTunnel(options: options)
        /*trafficReader = TrafficReader { [unowned self] traffic in
            trafficLock.lock()
            upload += traffic.up
            download += traffic.down
            trafficLock.unlock()
        }*/
        
        // Check for split tunneling configuration in options
        if let perAppProxyEnabled = options?["PerAppProxyEnabled"] as? NSString as? String,
           perAppProxyEnabled.lowercased() == "yes" || perAppProxyEnabled.lowercased() == "true" {
            
            let includeMode = (options?["PerAppProxyMode"] as? NSString as? String ?? "exclude").lowercased() == "include"
            
            if let appListString = options?["PerAppProxyList"] as? NSString as? String {
                let appList = appListString.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                await updateSplitTunnelingConfiguration(includeMode: includeMode, appList: appList)
            }
        }
    }
    
    override func handleAppMessage(_ messageData: Data) async -> Data? {
        let message = String(data: messageData, encoding: .utf8)
        switch message {
        case "stats":
            return "\(upload),\(download)".data(using: .utf8)!
        case let msg where msg.hasPrefix("split_tunnel:"):
            // Handle split tunneling commands
            let commandParts = msg.components(separatedBy: ":")
            if commandParts.count >= 3 {
                let command = commandParts[1]
                let param = commandParts[2]
                
                if command == "enable" {
                    // Enable split tunneling with the provided app list
                    let apps = param.components(separatedBy: ";")
                    await updateSplitTunnelingConfiguration(includeMode: true, appList: apps)
                    return "OK".data(using: .utf8)
                } else if command == "disable" {
                    // Disable split tunneling
                    try? resetAppBasedRouting()
                    return "OK".data(using: .utf8)
                } else if command == "is_routed" {
                    // Check if specific app is routed
                    let isRouted = isAppRoutedThroughVPN(bundleID: param)
                    return (isRouted ? "YES" : "NO").data(using: .utf8)
                }
            }
        default:
            return nil
        }
    }
}
            }
        }
    }
    
    override func handleAppMessage(_ messageData: Data) async -> Data? {
        let message = String(data: messageData, encoding: .utf8)
        switch message {
        case "stats":
            return "\(upload),\(download)".data(using: .utf8)!
        case let msg where msg.hasPrefix("split_tunnel:"):
            // Handle split tunneling commands
            let commandParts = msg.components(separatedBy: ":")
            if commandParts.count >= 3 {
                let command = commandParts[1]
                let param = commandParts[2]
                
                if command == "enable" {
                    // Enable split tunneling with the provided app list
                    let apps = param.components(separatedBy: ";")
                    await updateSplitTunnelingConfiguration(includeMode: true, appList: apps)
                    return "OK".data(using: .utf8)
                } else if command == "disable" {
                    // Disable split tunneling
                    try? resetAppBasedRouting()
                    return "OK".data(using: .utf8)
                } else if command == "is_routed" {
                    // Check if specific app is routed
                    let isRouted = isAppRoutedThroughVPN(bundleID: param)
                    return (isRouted ? "YES" : "NO").data(using: .utf8)
                }
            }
        default:
            return nil
        }
    }
}
            }
        }
    }
    
    override func handleAppMessage(_ messageData: Data) async -> Data? {
        let message = String(data: messageData, encoding: .utf8)
        switch message {
        case "stats":
            return "\(upload),\(download)".data(using: .utf8)!
        case let msg where msg.hasPrefix("split_tunnel:"):
            // Handle split tunneling commands
            let commandParts = msg.components(separatedBy: ":")
            if commandParts.count >= 3 {
                let command = commandParts[1]
                let param = commandParts[2]
                
                if command == "enable" {
                    // Enable split tunneling with the provided app list
                    let apps = param.components(separatedBy: ";")
                    await updateSplitTunnelingConfiguration(includeMode: true, appList: apps)
                    return "OK".data(using: .utf8)
                } else if command == "disable" {
                    // Disable split tunneling
                    try? resetAppBasedRouting()
                    return "OK".data(using: .utf8)
                } else if command == "is_routed" {
                    // Check if specific app is routed
                    let isRouted = isAppRoutedThroughVPN(bundleID: param)
                    return (isRouted ? "YES" : "NO").data(using: .utf8)
                }
            }
        default:
            return nil
        }
    }
}

