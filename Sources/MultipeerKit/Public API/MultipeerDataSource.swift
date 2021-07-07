import Foundation

/// An ObservableObject wrapper around ``MultipeerTransceiver``,
/// useful for use with `Combine` and SwiftUI apps.
@available(tvOS 13.0, *)
@available(OSX 10.15, *)
@available(iOS 13.0, *)
public final class MultipeerDataSource: ObservableObject {

    public let transceiver: MultipeerTransceiver

    /// Initializes a new data source.
    /// - Parameter transceiver: The transceiver to be used by this data source.
    /// Note that the data source will set ``MultipeerTransceiver/availablePeersDidChange`` on the
    /// transceiver, so if you wish to use that closure yourself, you
    /// won't be able to use the data source.
    public init(transceiver: MultipeerTransceiver) {
        self.transceiver = transceiver

        transceiver.availablePeersDidChange = { [weak self] peers in
            self?.availablePeers = peers
        }

        availablePeers = transceiver.availablePeers
    }

    /// Peers currently available for invitation, connection and data transmission.
    @Published public private(set) var availablePeers: [Peer] = []

}
