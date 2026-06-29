import Foundation
import Network
import Security

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
        case custom((Peer) throws -> (context: Data, timeout: TimeInterval)?)
        /// Use `.none` when you want to manually invite peers by calling
        /// ``MultipeerTransceiver/invite(_:with:timeout:completion:)``
        case none
    }

    /// Configures security-related aspects of the multipeer connection.
    public struct Security {

        /// Encryption preference for the underlying network connections.
        ///
        /// Replaces `MCEncryptionPreference` from the deprecated MultipeerConnectivity API.
        public enum EncryptionPreference {
            /// No transport encryption is used. Connections are plain TCP.
            case none
            /// TLS is used when available.
            ///
            /// The underlying `Network` framework does not support a true "TLS if
            /// available" mode — this case is currently treated the same as
            /// ``required`` and is kept only for source compatibility.
            /// Use ``required`` or ``none`` explicitly.
            @available(*, deprecated, message: "Use .required or .none. The Network framework does not support optional TLS; this case currently behaves the same as .required.")
            case optional
            /// TLS is required. Connections that cannot negotiate TLS will fail.
            case required
        }

        public typealias InvitationHandler = (Peer, Data?, @escaping (Bool) -> Void) -> Void

        /// An optional identity used to authenticate the local peer during TLS handshakes.
        ///
        /// When set, the identity is installed on the underlying `NWProtocolTLS` options
        /// and presented to remote peers during connection setup.
        public var identity: SecIdentity?

        /// Configure the level of encryption to be used for communications.
        public var encryptionPreference: EncryptionPreference

        /// A custom closure to be used when handling invitations received from remote peers.
        ///
        /// It receives the `Peer` that sent the invitation, a custom `Data` value
        /// that's a context that can be used to customize the invitation,
        /// and a closure to be called with `true` to accept the invitation or `false` to reject it.
        ///
        /// The default implementation accepts all invitations.
        public var invitationHandler: InvitationHandler

        public init(identity: SecIdentity?,
                    encryptionPreference: EncryptionPreference,
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
    /// MultipeerKit advertises and browses for the Bonjour service `_<serviceType>._tcp`.
    /// Service types must be 15 characters or fewer, contain only lowercase ASCII
    /// letters, digits and hyphens, and must contain at least one letter.
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
        peerName: LocalPeerIdentity.defaultDisplayName,
        defaults: .standard,
        security: .default,
        invitation: .automatic
    )

}
