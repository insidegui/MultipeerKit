import Foundation
import MultipeerConnectivity.MCPeerID
import os.log

extension MCPeerID {

    private static let defaultsKey = "_multipeerKit.mePeerID"

    private static func fetchExisting(with config: MultipeerConfiguration) -> MCPeerID? {
        guard let data = config.defaults.data(forKey: Self.defaultsKey) else { return nil }

        do {
            let peer = try NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data)

            guard peer?.displayName == config.peerName else { return nil }

            return peer
        } catch {
            return nil
        }
    }

    static func fetchOrCreate(with config: MultipeerConfiguration) -> MCPeerID {
        fetchExisting(with: config) ?? MCPeerID(displayName: config.peerName)
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
