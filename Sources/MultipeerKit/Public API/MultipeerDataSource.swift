import Foundation
import Combine

@available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
public typealias ObservablePeer = MultipeerDataSource.ObservablePeer

/// An ObservableObject wrapper around ``MultipeerTransceiver``,
/// useful for use with `Combine` and SwiftUI apps.
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public final class MultipeerDataSource: ObservableObject {

    public let transceiver: MultipeerTransceiver

    public static let isSwiftUIPreview: Bool = { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }()

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

        #if DEBUG
        if Self.isSwiftUIPreview {
            availablePeers.append(.mock)
        }
        #endif
    }

    /// Peers currently available for invitation, connection and data transmission.
    @Published public private(set) var availablePeers: [Peer] = []

    /// Manually invites a peer.
    ///
    /// For more details, read the documentation for ``MultipeerTransceiver/invite(_:with:timeout:completion:)``.
    public func invite(_ peer: Peer, with data: Data? = nil, timeout: TimeInterval = 30) async throws {
        try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
            guard let self else { return continuation.resume(throwing: CancellationError()) }

            self.transceiver.invite(peer, with: data, timeout: timeout) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Returns an ``ObservablePeer`` instance that automatically updates when the
    /// specified peer is updated, such as when it connects or disconnects.
    ///
    /// Use an observable peer as the input to a SwiftUI view if you'd like the view to be
    /// updated when the state of the observed peer changes, such as when it connects/disconnects from the local peer.
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
    public func observablePeer(_ peer: Peer) -> ObservablePeer {
        ObservablePeer(peer: peer, dataSource: self)
    }

    /// Convenient `ObservableObject` that tracks updates to the state of a specific ``Peer``.
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
    public final class ObservablePeer: ObservableObject {
        /// This is updated from the transceiver.
        /// If the peer goes away, this may be set to `nil`.
        /// Doesn't affect availability of the original `Peer` model to API clients,
        /// since that's stored on `init` and provided as fallback.
        @Published fileprivate var dynamicPeer: Peer?

        /// The peer that's being observed by the object.
        ///
        /// - note: Data on the peer might be stale if the remote peer goes away
        /// during the lifetime of the observable peer object. For connection state,
        /// prefer reading directly from the ``isConnected`` property.
        public var observedPeer: Peer { dynamicPeer ?? initialPeer }

        /// The unique identifier for the peer.
        public var id: String

        /// The peer's display name.
        public var name: String { dynamicPeer?.name ?? initialPeer.name }

        /// Discovery info provided by the peer.
        public var discoveryInfo: [String: String]? { dynamicPeer?.discoveryInfo ?? initialPeer.discoveryInfo }

        /// `true` if we are currently connected to this peer.
        public var isConnected: Bool { dynamicPeer?.isConnected ?? false }

        private lazy var cancellables = Set<AnyCancellable>()

        private let initialPeer: Peer

        fileprivate init(peer: Peer, dataSource: MultipeerDataSource?) {
            self.dynamicPeer = peer
            self.initialPeer = peer
            self.id = peer.id

            guard let dataSource else { return }

            dataSource
                .$availablePeers
                .map({ $0.first(where: { $0.id == peer.id }) })
                .removeDuplicates()
                .assign(to: &$dynamicPeer)
        }

        public static let mock = ObservablePeer(peer: .mock, dataSource: nil)
    }

}
