import Foundation

/// A stable identity for the local peer.
///
/// MultipeerKit persists a UUID per ``MultipeerConfiguration/peerName`` so that
/// the peer ID stays the same across launches. If the configured peer name
/// changes, a new identifier is generated.
struct LocalPeerIdentity {
    let id: String
    let name: String

    private static let idDefaultsKey = "_multipeerKit.localPeerID"
    private static let nameDefaultsKey = "_multipeerKit.localPeerName"

    static func fetchOrCreate(with config: MultipeerConfiguration) -> LocalPeerIdentity {
        let defaults = config.defaults

        if let existingID = defaults.string(forKey: idDefaultsKey),
           let existingName = defaults.string(forKey: nameDefaultsKey),
           existingName == config.peerName
        {
            return LocalPeerIdentity(id: existingID, name: existingName)
        }

        let id = UUID().uuidString
        defaults.set(id, forKey: idDefaultsKey)
        defaults.set(config.peerName, forKey: nameDefaultsKey)
        return LocalPeerIdentity(id: id, name: config.peerName)
    }
}

#if canImport(UIKit)
import UIKit

extension LocalPeerIdentity {
    static var defaultDisplayName: String { UIDevice.current.name }
}

#elseif canImport(AppKit)
import AppKit

extension LocalPeerIdentity {
    static var defaultDisplayName: String { Host.current().localizedName ?? "Unknown Mac" }
}

#else

extension LocalPeerIdentity {
    static var defaultDisplayName: String { "Unknown" }
}

#endif
