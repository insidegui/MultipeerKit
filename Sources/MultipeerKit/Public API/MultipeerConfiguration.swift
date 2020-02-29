import Foundation
import MultipeerConnectivity

public struct MultipeerConfiguration {

    public struct Security {

        public let identity: [Any]?
        public let encryptionPreference: MCEncryptionPreference
        public let invitationHandler: (Peer, Data?, (Bool) -> Void) -> Void

        public static let `default` = Security(identity: nil, encryptionPreference: .none, invitationHandler: { _, _, closure in
            closure(true)
        })

    }

    public var serviceType: String
    public var peerName: String
    public var defaults: UserDefaults
    public var security: Security

    public init(serviceType: String,
                peerName: String,
                defaults: UserDefaults,
                security: Security)
    {
        precondition(peerName.utf8.count <= 63, "peerName can't be longer than 63 bytes")

        self.serviceType = serviceType
        self.peerName = peerName
        self.defaults = defaults
        self.security = security
    }

    public static let `default` = MultipeerConfiguration(
        serviceType: "MKSVC",
        peerName: MCPeerID.defaultDisplayName,
        defaults: .standard,
        security: .default
    )

}
