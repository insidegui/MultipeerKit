import Foundation
import MultipeerConnectivity

/// Configures several aspects of the multipeer communication.
public struct MultipeerConfiguration {

    /// Defines how the multipeer connection handles newly discovered peers.
    /// New peers can be invited automatically, invited with a custom context and timeout,
    /// or not invited at all, in which case you must invite them manually.
    public enum Invitation {
        /// When `.automatic` is used, all found peers will be immediately invited to join the session.
        case automatic
        /// Use `.custom` when you want to control the invitation of new peers to your session,
        /// but still invite them at the time of discovery.
        case custom((Peer) -> (context: Data, timeout: TimeInterval)?)
        /// Use `.none` when you want to manually invite peers by calling `invite` in `MultipeerTransceiver`.
        case none
    }

    /// Configures security-related aspects of the multipeer connection.
    public struct Security {

        public typealias InvitationHandler = (Peer, Data?, (Bool) -> Void) -> Void

        /// An array of information that can be used to identify the peer to other nearby peers.
        ///
        /// The first object in this array should be a `SecIdentity` object that provides the local peer’s identity.
        ///
        /// The remainder of the array should contain zero or more additional SecCertificate objects that provide any
        /// intermediate certificates that nearby peers might require when verifying the local peer’s identity.
        /// These certificates should be sent in certificate chain order.
        ///
        /// Check Apple's `MCSession` docs for more information.
        public var identity: [Any]?

        /// Configure the level of encryption to be used for communications.
        public var encryptionPreference: MCEncryptionPreference

        /// A custom closure to be used when handling invitations received by remote peers.
        ///
        /// It receives the `Peer` that sent the invitation, a custom `Data` value
        /// that's a context that can be used to customize the invitation,
        /// and a closure to be called with `true` to accept the invitation or `false` to reject it.
        ///
        /// The default implementation accepts all invitations.
        public var invitationHandler: InvitationHandler

        public init(identity: [Any]?,
                    encryptionPreference: MCEncryptionPreference,
                    invitationHandler: @escaping InvitationHandler)
        {
            self.identity = identity
            self.encryptionPreference = encryptionPreference
            self.invitationHandler = invitationHandler
        }

        /// The default security configuration, which has no identity, uses no encryption and accepts all invitations.
        public static let `default` = Security(identity: nil, encryptionPreference: .none, invitationHandler: { _, _, closure in
            closure(true)
        })

    }

    /// This must be the same accross your app running on multiple devices,
    /// it must be a short string.
    ///
    /// Check Apple's docs on `MCNearbyServiceAdvertiser` for more info on the limitations for this field.
    public var serviceType: String

    /// A display name for this peer that will be shown to nearby peers.
    public var peerName: String

    /// An instance of `UserDefaults` that's used to store this peer's identity so that it
    /// remains stable between different sessions. If you use MultipeerKit in app extensions,
    /// make sure to use a shared app group if you wish to maintain a stable identity.
    public var defaults: UserDefaults

    /// The security configuration.
    public var security: Security

    /// Defines how the multipeer connection handles newly discovered peers.
    public var invitation: Invitation

    /// Creates a new configuration.
    /// - Parameters:
    ///   - serviceType: This must be the same accross your app running on multiple devices,
    ///   it must be a short string.
    ///   Check Apple's docs on `MCNearbyServiceAdvertiser` for more info on the limitations for this field.
    ///   - peerName: A display name for this peer that will be shown to nearby peers.
    ///   - defaults: An instance of `UserDefaults` that's used to store this peer's identity so that it
    ///   remains stable between different sessions. If you use MultipeerKit in app extension
    ///   make sure to use a shared app group if you wish to maintain a stable identity.
    ///   - security: The security configuration.
    ///   - invitation: Defines how the multipeer connection handles newly discovered peers.
    ///   New peers can be invited automatically, invited with a custom context
    ///   or not invited at all, in which case you must invite them manually.
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

    /// The default configuration, uses the service type `MKSVC`, the name of the device/computer as the
    /// display name, `UserDefaults.standard`, the default security configuration and automatic invitation.
    public static let `default` = MultipeerConfiguration(
        serviceType: "MKSVC",
        peerName: MCPeerID.defaultDisplayName,
        defaults: .standard,
        security: .default,
        invitation: .automatic
    )

}
