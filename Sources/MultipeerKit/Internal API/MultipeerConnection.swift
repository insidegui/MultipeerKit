import Foundation
import MultipeerConnectivity
import os.log

public typealias InvitationCompletionHandler = (_ result: Result<Peer, Error>) -> Void

public struct MultipeerError: LocalizedError {
    public var localizedDescription: String
}

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

    var didReceiveData: ((Data, PeerName) -> Void)?
    var didFindPeer: ((Peer) -> Void)?
    var didLosePeer: ((Peer) -> Void)?
    var didConnectToPeer: ((Peer) -> Void)?
    var didDisconnectFromPeer: ((Peer) -> Void)?

    private var discoveredPeers: [MCPeerID: Peer] = [:]

    func resume() {
        os_log("%{public}@", log: log, type: .debug, #function)

        if modes.contains(.receiver) {
            advertiser.startAdvertisingPeer()
        }
        if modes.contains(.transmitter) {
            browser.startBrowsingForPeers()
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

    private lazy var browser: MCNearbyServiceBrowser = {
        let b = MCNearbyServiceBrowser(peer: me, serviceType: configuration.serviceType)

        b.delegate = self

        return b
    }()

    private lazy var advertiser: MCNearbyServiceAdvertiser = {
        let a = MCNearbyServiceAdvertiser(peer: me, discoveryInfo: nil, serviceType: configuration.serviceType)

        a.delegate = self

        return a
    }()

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

    private var invitationCompletionHandlers: [MCPeerID: InvitationCompletionHandler] = [:]

    func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?) {
        invitationCompletionHandlers[peer.underlyingPeer] = completion

        browser.invitePeer(peer.underlyingPeer, to: session, withContext: context, timeout: timeout)
    }

}

// MARK: - Session delegate

extension MultipeerConnection: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        os_log("%{public}@", log: log, type: .debug, #function)

        guard let peer = discoveredPeers[peerID] else { return }

        let handler = invitationCompletionHandlers[peerID]

        defer { invitationCompletionHandlers[peerID] = nil }

        DispatchQueue.main.async {
            switch state {
            case .connected:
                handler?(.success(peer))

                self.didConnectToPeer?(peer)
            case .notConnected:
                handler?(.failure(MultipeerError(localizedDescription: "Failed to connect to peer.")))

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

        didReceiveData?(data, peerID.displayName)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        os_log("%{public}@", log: log, type: .debug, #function)
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        os_log("%{public}@", log: log, type: .debug, #function)
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        os_log("%{public}@", log: log, type: .debug, #function)
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
                guard let invite = inviter(peer) else {
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

}

// MARK: - Advertiser delegate

extension MultipeerConnection: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)

        guard let peer = discoveredPeers[peerID] else { return }

        configuration.security.invitationHandler(peer, context, { decision in
            invitationHandler(decision, decision ? session : nil)
        })
    }

}
