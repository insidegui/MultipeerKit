import Foundation

/// First frame exchanged between two peers after a TCP connection is
/// established. Carries the sender's stable identity plus an optional
/// invitation context and, when application-layer encryption is enabled,
/// an ephemeral X25519 public key for ECDH key agreement.
struct HandshakeMessage: Codable {
    let id: String
    let name: String
    let discoveryInfo: [String: String]?
    let context: Data?
    /// Raw 32-byte X25519 public key. Present when the sender wants
    /// application-layer encryption negotiated for this connection.
    let ephemeralPublicKey: Data?
}
