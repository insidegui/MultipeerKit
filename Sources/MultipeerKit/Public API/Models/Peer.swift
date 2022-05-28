import Foundation
import MultipeerConnectivity.MCPeerID
import CommonCrypto

/// Represents a remote peer.
public struct Peer: Identifiable {

    let underlyingPeer: MCPeerID

    /// The unique identifier for the peer.
    public let id: String

    /// The peer's display name.
    public let name: String

    /// Discovery info provided by the peer.
    public let discoveryInfo: [String: String]?

    /// `true` if we are currently connected to this peer.
    public internal(set) var isConnected: Bool

    public var userInfo: [String: Any]

    init(peer: MCPeerID, discoveryInfo: [String: String]?) throws {
        /**
         According to Apple's docs, every MCPeerID is unique, therefore encoding it
         and hashing the resulting data is a good way to generate an unique identifier
         that will be always the same for the same peer ID.
         */
        let peerData = try NSKeyedArchiver.archivedData(withRootObject: peer, requiringSecureCoding: true)
        self.id = peerData.idHash

        self.underlyingPeer = peer
        self.name = peer.displayName
        self.discoveryInfo = discoveryInfo
        self.isConnected = false
        self.userInfo = [:]
    }

}

extension Peer: Equatable {

    public static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.underlyingPeer == rhs.underlyingPeer &&
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.discoveryInfo == rhs.discoveryInfo &&
        lhs.isConnected == rhs.isConnected
    }

}

extension Peer: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(underlyingPeer)
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(discoveryInfo)
        hasher.combine(isConnected)
    }
}

fileprivate extension Data {

    var idHash: String {
        var sha1 = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))

        withUnsafeBytes { _ = CC_SHA1($0.baseAddress, CC_LONG(count), &sha1) }

        return sha1.map({ String(format: "%02hhx", $0) }).joined()
    }

}
