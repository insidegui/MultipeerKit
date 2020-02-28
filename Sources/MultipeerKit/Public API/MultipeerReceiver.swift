import Foundation
import MultipeerConnectivity.MCPeerID
import os.log

struct ReceiveHandler<T: Decodable> {
    let handle: (T) -> Void
}

struct MultipeerMessage: Hashable, Codable {
    let typeName: String
    let payload: Data?
}

public final class MultipeerReceiver {

    private let log = MultipeerKit.log(for: MultipeerReceiver.self)

    private let connection: MultipeerConnection

    public init(configuration: MultipeerConfiguration = .default) {
        self.connection = MultipeerConnection(
            mode: .receiver,
            configuration: configuration
        )

        connection.didReceiveData = { [weak self] data, peer in
            self?.handleDataReceived(data, from: peer)
        }
    }

    public func receive<T: Decodable>(_ type: T.Type, using closure: @escaping (T) -> Void) {
        // Problem: need to store the handler for later use. How do we do that, given that the
        // handler is generic? 🤔
    }

    public func resume() {
        connection.resume()
    }

    public func stop() {
        connection.stop()
    }

    private func handleDataReceived(_ data: Data, from peer: MCPeerID) {
        os_log("%{public}@", log: log, type: .debug, #function)
        // Here we don't know the type of data so that we can find the correct
        // handler for it. Encapsulate every message as a `MultipeerMessage`? 🤔
        // If we do encapsulate, how do we then fetch the correct handler to call?
    }

}
