import Foundation
import MultipeerConnectivity.MCPeerID

public struct MultipeerConfiguration {

    public let serviceType: String
    public let peerName: String
    public let defaults: UserDefaults

    public init(serviceType: String, peerName: String, defaults: UserDefaults) {
        precondition(peerName.utf8.count <= 63, "peerName can't be longer than 63 bytes")

        self.serviceType = serviceType
        self.peerName = peerName
        self.defaults = defaults
    }

    public static let `default` = MultipeerConfiguration(
        serviceType: "MKSVC",
        peerName: MCPeerID.defaultDisplayName,
        defaults: .standard
    )

}
