import Foundation
import Network

/// Represents a remote peer.
public struct Peer: Hashable, Identifiable {

    /// The unique identifier for the peer.
    public let id: String

    /// The peer's display name.
    public let name: String

    /// Discovery info provided by the peer.
    public let discoveryInfo: [String: String]?

    /// `true` if we are currently connected to this peer.
    public internal(set) var isConnected: Bool

    /// The network endpoint used to reach this peer. `nil` for the local peer
    /// and for peers that were not discovered via the network browser (for
    /// example, peers materialized from an incoming connection's hello frame).
    var endpoint: NWEndpoint?

    init(id: String,
         name: String,
         discoveryInfo: [String: String]?,
         endpoint: NWEndpoint? = nil,
         isConnected: Bool = false)
    {
        self.id = id
        self.name = name
        self.discoveryInfo = discoveryInfo
        self.endpoint = endpoint
        self.isConnected = isConnected
    }

    public static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
