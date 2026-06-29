import Foundation

/// First frame exchanged between two peers after a TCP connection is
/// established. Carries the sender's stable identity plus an optional
/// invitation context.
struct HandshakeMessage: Codable {
    let id: String
    let name: String
    let discoveryInfo: [String: String]?
    let context: Data?
}
