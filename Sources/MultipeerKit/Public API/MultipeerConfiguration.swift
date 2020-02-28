import Foundation
import MultipeerConnectivity.MCPeerID

public struct MultipeerConfiguration {

    public let serviceType: String
    public let peerName: String
    public let defaults: UserDefaults

    public init(serviceType: String, peerName: String, defaults: UserDefaults) {
        self.serviceType = serviceType
        self.peerName = peerName
        self.defaults = defaults
    }

    public static let `default` = MultipeerConfiguration(
        serviceType: "MultipeerKit",
        peerName: MCPeerID.defaultDisplayName,
        defaults: .standard
    )

}
