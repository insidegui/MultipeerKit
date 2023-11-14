import Foundation
import MultipeerConnectivity
import os.log

/// The completion handler called when the remote peer responds to a manual invite initiated
/// by calling ``MultipeerTransceiver/invite(_:with:timeout:completion:)``.
public typealias InvitationCompletionHandler = (_ result: Result<Peer, Error>) -> Void

public struct MultipeerError: LocalizedError {
    public var localizedDescription: String
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public typealias ResourceUploadStream = AsyncThrowingStream<Double, Error>

final class MultipeerConnection: NSObject, MultipeerProtocol {

    enum Mode: Int, CaseIterable {
        case receiver
        case transmitter
    }

    private let log = MultipeerKit.log(for: MultipeerConnection.self)

    let modes: [Mode]
    let configuration: MultipeerConfiguration
    let me: MCPeerID

    init(modes: [Mode] = Mode.allCases, configuration: MultipeerConfiguration = .default) {
        self.modes = modes
        self.configuration = configuration
        self.me = MCPeerID.fetchOrCreate(with: configuration)
    }

    var didReceiveData: ((Data, Peer) -> Void)?
    var didFindPeer: ((Peer) -> Void)?
    var didLosePeer: ((Peer) -> Void)?
    var didConnectToPeer: ((Peer) -> Void)?
    var didDisconnectFromPeer: ((Peer) -> Void)?
    var didStartReceivingResource: ((_ sender: Peer, _ resourceName: String, _ progress: Progress) -> Void)?
    var didFinishReceivingResource: ((_ sender: Peer, _ resourceName: String, _ result: Result<URL, Error>) -> Void)?

    private var discoveredPeers: [MCPeerID: Peer] = [:]

    func resume() {
        os_log("%{public}@", log: log, type: .debug, #function)

        if modes.contains(.transmitter) {
            // Ideally, we'd just keep using the same browser for the lifetime of the MultipeerConnection object.
            // However, due to #12, we can't. The same process is done with the advertiser for consistency.
            browser = makeBrowser()
            browser.startBrowsingForPeers()
        }
        if modes.contains(.receiver) {
            advertiser = makeAdvertiser()
            advertiser.startAdvertisingPeer()
        }
    }

    func stop() {
        os_log("%{public}@", log: log, type: .debug, #function)

        if modes.contains(.receiver) {
            advertiser.stopAdvertisingPeer()
        }
        if modes.contains(.transmitter) {
            browser.stopBrowsingForPeers()
        }
    }

    private lazy var session: MCSession = {
        let s = MCSession(
            peer: me,
            securityIdentity: configuration.security.identity,
            encryptionPreference: configuration.security.encryptionPreference
        )

        s.delegate = self

        return s
    }()

    private func makeBrowser() -> MCNearbyServiceBrowser {
        let b = MCNearbyServiceBrowser(peer: me, serviceType: configuration.serviceType)

        b.delegate = self

        return b
    }

    private lazy var browser: MCNearbyServiceBrowser = { makeBrowser() }()

    private func makeAdvertiser() -> MCNearbyServiceAdvertiser {
        let a = MCNearbyServiceAdvertiser(peer: me, discoveryInfo: nil, serviceType: configuration.serviceType)

        a.delegate = self

        return a
    }
    
    private lazy var advertiser: MCNearbyServiceAdvertiser = { makeAdvertiser() }()

    func broadcast(_ data: Data) throws {
        guard !session.connectedPeers.isEmpty else {
            os_log("Not broadcasting message: no connected peers", log: self.log, type: .error)
            return
        }

        try session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    func send(_ data: Data, to peers: [Peer]) throws {
        let ids = peers.map { $0.underlyingPeer }
        try session.send(data, toPeers: ids, with: .reliable)
    }

    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    func send(_ resourceURL: URL, to peer: Peer) -> ResourceUploadStream {
        AsyncThrowingStream { [weak self] continuation in
            guard let self else {
                return continuation.finish(throwing: CancellationError())
            }

            guard resourceURL.isFileURL else {
                return continuation.finish(throwing: MultipeerError(localizedDescription: "Resource must be a local file URL, remote URLs are not supported."))
            }

            let peerID = peer.underlyingPeer

            /// Ensure resource names are unique even if the file name is the same, while keeping the file name to aid in debugging.
            let resourceID = "\(UUID().uuidString)-\(resourceURL.lastPathComponent)"

            let progress = session.sendResource(at: resourceURL, withName: resourceID, toPeer: peerID) { error in
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }

            guard let progress else {
                return continuation.finish(throwing: MultipeerError(localizedDescription: "Failed to start resource upload."))
            }

            let cancellable = progress.publisher(for: \.fractionCompleted).sink { progress in
                continuation.yield(progress)
            }

            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }
    }

    private var invitationCompletionHandlers: [MCPeerID: InvitationCompletionHandler] = [:]

    func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?) {
        invitationCompletionHandlers[peer.underlyingPeer] = completion

        browser.invitePeer(peer.underlyingPeer, to: session, withContext: context, timeout: timeout)
    }
    
    func getLocalPeer() -> Peer? {
        return try? Peer(peer: me, discoveryInfo: nil)
    }

}

// MARK: - Session delegate

extension MultipeerConnection: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        os_log("%{public}@", log: log, type: .debug, #function)

        DispatchQueue.main.async {
            guard let peer = self.discoveredPeers[peerID] else { return }
    
            let handler = self.invitationCompletionHandlers[peerID]
    
            switch state {
            case .connected:
                handler?(.success(peer))
                self.invitationCompletionHandlers[peerID] = nil
                self.didConnectToPeer?(peer)
            case .notConnected:
                handler?(.failure(MultipeerError(localizedDescription: "Failed to connect to peer.")))
                self.invitationCompletionHandlers[peerID] = nil
                self.didDisconnectFromPeer?(peer)
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        os_log("%{public}@", log: log, type: .debug, #function)

        do {
            let peer = try Peer(peer: peerID, discoveryInfo: nil)
            didReceiveData?(data, peer)
        } catch {
            os_log("Received data, but cannot create peer for %@: %{public}@", log: log, type: .error, #function, peerID.displayName, String(describing: error))
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        os_log("%{public}@", log: log, type: .debug, #function)
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        os_log("%{public}@", log: log, type: .debug, #function)

        do {
            let peer = try Peer(peer: peerID, discoveryInfo: nil)
            
            didStartReceivingResource?(peer, resourceName, progress)
        } catch {
            os_log("Started receiving resource, but cannot create peer for %@: %{public}@", log: log, type: .error, #function, peerID.displayName, String(describing: error))
        }
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        os_log("%{public}@", log: log, type: .debug, #function)

        do {
            let peer = try Peer(peer: peerID, discoveryInfo: nil)

            let result: Result<URL, Error>
            if let localURL {
                result = .success(localURL)
            } else {
                result = .failure(error ?? MultipeerError(localizedDescription: "Unknown MultipeerConnectivity error."))
            }

            didFinishReceivingResource?(peer, resourceName, result)
        } catch {
            os_log("Finished receiving resource, but cannot create peer for %@: %{public}@", log: log, type: .error, #function, peerID.displayName, String(describing: error))
        }
    }

}

// MARK: - Browser delegate

extension MultipeerConnection: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        os_log("%{public}@", log: log, type: .debug, #function)

        do {
            let peer = try Peer(peer: peerID, discoveryInfo: info)

            discoveredPeers[peerID] = peer

            didFindPeer?(peer)

            switch configuration.invitation {
            case .automatic:
                browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10.0)
            case .custom(let inviter):
                guard let invite = try inviter(peer) else {
                    os_log("Custom invite not sent for peer %@", log: self.log, type: .error, String(describing: peer))
                    return
                }

                browser.invitePeer(
                    peerID,
                    to: session,
                    withContext: invite.context,
                    timeout: invite.timeout
                )
            case .none:
                os_log("Auto-invite disabled", log: self.log, type: .debug)
                return
            }
        } catch {
            os_log("Failed to initialize peer based on peer ID %@: %{public}@", log: self.log, type: .error, String(describing: peerID), String(describing: error))
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        os_log("%{public}@", log: log, type: .debug, #function)

        guard let peer = discoveredPeers[peerID] else { return }

        didLosePeer?(peer)

        discoveredPeers[peerID] = nil
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        os_log("The multipeer connection failed to start browsing for peers. This could be due to missing keys in your app's Info.plist, check out the documentation at http://github.com/insidegui/MultipeerKit for more information. Error: %{public}@", log: log, type: .fault, String(describing: error))
    }

}

// MARK: - Advertiser delegate

extension MultipeerConnection: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)

        DispatchQueue.main.async {
            guard let peer = self.discoveredPeers[peerID] else { return }

            self.configuration.security.invitationHandler(peer, context, { [weak self] decision in
                guard let self = self else { return }

                invitationHandler(decision, decision ? self.session : nil)
            })
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        os_log("The multipeer connection failed to start advertising to peers. This could be due to missing keys in your app's Info.plist, check out the documentation at http://github.com/insidegui/MultipeerKit for more information. Error: %{public}@", log: log, type: .fault, String(describing: error))
    }

}
