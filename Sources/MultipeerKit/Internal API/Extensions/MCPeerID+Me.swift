import Foundation
import MultipeerConnectivity.MCPeerID
import os.log

extension MCPeerID {
    
    private static let log = OSLog(subsystem: MultipeerKit.subsystemName, category: "MCPeerID")

    private static func fetchExisting(with config: MultipeerConfiguration) -> MCPeerID? {
        guard let data = config.defaults.data(forKey: config.defaultsKey) else { return nil }

        do {
            let peer = try NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data)

            guard peer?.displayName == config.peerName else { return nil }

            return peer
        } catch {
            return nil
        }
    }
    
    private static func store(_ id: MCPeerID, with config: MultipeerConfiguration) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: id, requiringSecureCoding: true)
            
            config.defaults.set(data, forKey: config.defaultsKey)
            config.defaults.synchronize()
        } catch {
            os_log("Failed to archive peerID for storage: %{public}@", log: self.log, type: .error, String(describing: error))
        }
    }

    static func fetchOrCreate(with config: MultipeerConfiguration) -> MCPeerID {
        if let existingID = fetchExisting(with: config) {
            os_log("Fetched existing peer ID %@", log: self.log, type: .debug, String(describing: existingID))
            
            return existingID
        } else {
            let newID = MCPeerID(displayName: config.peerName)
            
            os_log("Generated new peer ID %@ for service %@", log: self.log, type: .debug, String(describing: newID), config.serviceType)
            
            store(newID, with: config)
            
            return newID
        }
    }

}

#if os(iOS) || os(tvOS)
import UIKit

public extension MCPeerID {
    static var defaultDisplayName: String { UIDevice.current.name }
}

#else

import Cocoa

public extension MCPeerID {
    static var defaultDisplayName: String { Host.current().localizedName ?? "Unknown Mac" }
}

#endif
