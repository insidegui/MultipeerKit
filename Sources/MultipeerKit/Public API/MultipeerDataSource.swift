import Foundation

@available(OSX 10.15, *)
@available(iOS 13.0, *)
/// This class can be used to monitor nearby peers in a reactive way,
/// it's especially useful for SwiftUI apps.
public final class MultipeerDataSource: ObservableObject {

    public let transceiver: MultipeerTransceiver

    /// Initializes a new data source.
    /// - Parameter transceiver: The transceiver to be used by this data source.
    /// Note that the data source will set `availablePeersDidChange` on the
    /// transceiver, so if you wish to use that closure yourself, you
    /// won't be able to use the data source.
    public init(transceiver: MultipeerTransceiver) {
        self.transceiver = transceiver

        transceiver.availablePeersDidChange = { [weak self] peers in
            self?.availablePeers = peers
        }
    }

    /// Peers currently available for invitation, connection and data transmission.
    @Published public private(set) var availablePeers: [Peer] = []

}
