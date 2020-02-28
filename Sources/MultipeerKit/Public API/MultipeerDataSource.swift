import Foundation

@available(iOS 13.0, *)
public final class MultipeerDataSource: ObservableObject {

    public let transceiver: MultipeerTransceiver

    public init(transceiver: MultipeerTransceiver) {
        self.transceiver = transceiver

        transceiver.availablePeersDidChange = { [weak self] peers in
            self?.availablePeers = peers
        }
    }

    @Published public private(set) var availablePeers: [Peer] = []

}
