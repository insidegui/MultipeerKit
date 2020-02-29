import Foundation
import MultipeerConnectivity.MCPeerID
import os.log

public final class MultipeerTransceiver {

    private let log = MultipeerKit.log(for: MultipeerTransceiver.self)

    let connection: MultipeerProtocol

    public var availablePeersDidChange: ([Peer]) -> Void = { _ in }

    public var availablePeers: [Peer] = [] {
        didSet {
            guard availablePeers != oldValue else { return }

            DispatchQueue.main.async {
                self.availablePeersDidChange(self.availablePeers)
            }
        }
    }

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
    }

    public func receive<T: Codable>(_ type: T.Type, using closure: @escaping (T) -> Void) {
        MultipeerMessage.register(type, for: String(describing: type), closure: closure)
    }

    public func resume() {
        connection.resume()
    }

    public func stop() {
        connection.stop()
    }

    public func broadcast<T: Encodable>(_ payload: T) {
        do {
            let message = MultipeerMessage(type: String(describing: T.self), payload: payload)

            let data = try JSONEncoder().encode(message)

            try connection.broadcast(data)
        } catch {
            os_log("Failed to send payload %@: %{public}@", log: self.log, type: .error, String(describing: payload), String(describing: error))
        }
    }

    public func send<T: Encodable>(_ payload: T, to peers: [Peer]) {
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

    private func handlePeerAdded(_ peer: Peer) {
        guard !availablePeers.contains(peer) else { return }

        availablePeers.append(peer)
    }

    private func handlePeerRemoved(_ peer: Peer) {
        guard let idx = availablePeers.firstIndex(of: peer) else { return }

        availablePeers.remove(at: idx)
    }

}
