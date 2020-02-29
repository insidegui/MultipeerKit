import Foundation
import MultipeerConnectivity

/// Configures several aspects of the multipeer communication.
public struct MultipeerConfiguration {

    /// Defines how to handle inviting found peers to join our session.
    public enum Invitation {
        /// When `.automatic` is used, all found peers will be immediately invited to join the session.
        case automatic
        /// Use `.custom` when you want to control the invitation of new peers to your session,
        /// but still invite them at the time of discovery.
        case custom((Peer) -> (context: Data, timeout: TimeInterval)?)
        /// Use `.none` when you want to manually invite peers by calling `invite` in `MultipeerTransceiver`.
        case none
    }

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
    public var invitation: Invitation

    public init(serviceType: String,
                peerName: String,
                defaults: UserDefaults,
                security: Security,
                invitation: Invitation)
    {
        precondition(peerName.utf8.count <= 63, "peerName can't be longer than 63 bytes")

        self.serviceType = serviceType
        self.peerName = peerName
        self.defaults = defaults
        self.security = security
        self.invitation = invitation
    }

    public static let `default` = MultipeerConfiguration(
        serviceType: "MKSVC",
        peerName: MCPeerID.defaultDisplayName,
        defaults: .standard,
        security: .default,
        invitation: .automatic
    )

}
