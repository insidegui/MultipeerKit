import Foundation
import MultipeerConnectivity.MCPeerID
import os.log

/// Handles all aspects related to the multipeer communication.
public final class MultipeerTransceiver {

    private let log = MultipeerKit.log(for: MultipeerTransceiver.self)

    let connection: MultipeerProtocol

    /// Called on the main queue when available peers have changed (new peers discovered or peers removed).
    public var availablePeersDidChange: ([Peer]) -> Void = { _ in }

    /// All peers currently available for invitation, connection and data transmission.
    public var availablePeers: [Peer] = [] {
        didSet {
            guard availablePeers != oldValue else { return }

            DispatchQueue.main.async {
                self.availablePeersDidChange(self.availablePeers)
            }
        }
    }

    /// Initializes a new transceiver.
    /// - Parameter configuration: The configuration, uses the default configuration if none specified.
    public init(configuration: MultipeerConfiguration = .default) {
        self.connection = MultipeerConnection(
            modes: MultipeerConnection.Mode.allCases,
            configuration: configuration
        )

        configure(connection)
    }

    init(connection: MultipeerProtocol) {
        self.connection = connection

        configure(connection)
    }

    private func configure(_ connection: MultipeerProtocol) {
        connection.didReceiveData = { [weak self] data, peer in
            self?.handleDataReceived(data, from: peer)
        }
        connection.didFindPeer = { [weak self] peer in
            DispatchQueue.main.async { self?.handlePeerAdded(peer) }
        }
        connection.didLosePeer = { [weak self] peer in
            DispatchQueue.main.async { self?.handlePeerRemoved(peer) }
        }
        connection.didConnectToPeer = { [weak self] peer in
            DispatchQueue.main.async { self?.handlePeerConnected(peer) }
        }
        connection.didDisconnectFromPeer = { [weak self] peer in
            DispatchQueue.main.async { self?.handlePeerDisconnected(peer) }
        }
    }

    /// Configures a new handler for a specific `Codable` type.
    /// - Parameters:
    ///   - type: The `Codable` type to receive.
    ///   - closure: The closure that will be called whenever a payload of the specified type is received.
    ///   - payload: The payload decoded from the remote message.
    ///
    /// MultipeerKit communicates data between peers as JSON-encoded payloads which originate with
    /// `Codable` entities. You register a closure to handle each specific type of entity,
    /// and this closure is automatically called by the framework when a remote peer sends
    /// a message containing an entity that decodes to the specified type.
    public func receive<T: Codable>(_ type: T.Type, using closure: @escaping (_ payload: T) -> Void) {
        MultipeerMessage.register(type, for: String(describing: type), closure: closure)
    }

    /// Resumes the transceiver, allowing this peer to be discovered and to discover remote peers.
    public func resume() {
        connection.resume()
    }

    /// Stops the transceiver, preventing this peer from discovering and being discovered.
    public func stop() {
        connection.stop()
    }

    /// Sends a message to all connected peers.
    /// - Parameter payload: The payload to be sent.
    public func broadcast<T: Encodable>(_ payload: T) {
        MultipeerMessage.register(T.self, for: String(describing: T.self))

        do {
            let message = MultipeerMessage(type: String(describing: T.self), payload: payload)

            let data = try JSONEncoder().encode(message)

            try connection.broadcast(data)
        } catch {
            os_log("Failed to send payload %@: %{public}@", log: self.log, type: .error, String(describing: payload), String(describing: error))
        }
    }

    /// Sends a message to a specific peer.
    /// - Parameters:
    ///   - payload: The payload to be sent.
    ///   - peers: An array of peers to send the message to.
    public func send<T: Encodable>(_ payload: T, to peers: [Peer]) {
        MultipeerMessage.register(T.self, for: String(describing: T.self))
        
        do {
            let message = MultipeerMessage(type: String(describing: T.self), payload: payload)

            let data = try JSONEncoder().encode(message)

            try connection.send(data, to: peers)
        } catch {
            os_log("Failed to send payload %@: %{public}@", log: self.log, type: .error, String(describing: payload), String(describing: error))
        }
    }

    private func handleDataReceived(_ data: Data, from peer: PeerName) {
        os_log("%{public}@", log: log, type: .debug, #function)

        do {
            let message = try JSONDecoder().decode(MultipeerMessage.self, from: data)

            os_log("Received message %@", log: self.log, type: .debug, String(describing: message))
        } catch {
            os_log("Failed to decode message: %{public}@", log: self.log, type: .error, String(describing: error))
        }
    }

    /// Manually invite a peer for communicating.
    /// - Parameters:
    ///   - peer: The peer to be invited.
    ///   - context: Custom data to be sent alongside the invitation.
    ///   - timeout: How long to wait for the remote peer to accept the invitation.
    ///   - completion: Called when the invitation succeeds or fails.
    ///
    /// You can call this method to manually invite a peer for communicating if you set the
    /// `invitation` parameter to `.none` in the transceiver's `configuration`.
    ///
    /// - warning: If the invitation parameter is not set to `.none`, you shouldn't call this method,
    /// since the transceiver does the inviting automatically.
    public func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?) {
        connection.invite(peer, with: context, timeout: timeout, completion: completion)
    }

    private func handlePeerAdded(_ peer: Peer) {
        guard !availablePeers.contains(peer) else { return }

        availablePeers.append(peer)
    }

    private func handlePeerRemoved(_ peer: Peer) {
        guard let idx = availablePeers.firstIndex(of: peer) else { return }

        availablePeers.remove(at: idx)
    }

    private func handlePeerConnected(_ peer: Peer) {
        setConnected(true, on: peer)
    }

    private func handlePeerDisconnected(_ peer: Peer) {
        setConnected(false, on: peer)
    }

    private func setConnected(_ connected: Bool, on peer: Peer) {
        guard let idx = availablePeers.firstIndex(of: peer) else { return }

        var mutablePeer = availablePeers[idx]
        mutablePeer.isConnected = connected
        availablePeers[idx] = mutablePeer
    }

}
