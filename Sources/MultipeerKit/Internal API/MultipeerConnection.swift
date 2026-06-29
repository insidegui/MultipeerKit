import Foundation
import Network
import os.log

/// The completion handler called when the remote peer responds to a manual invite initiated
/// by calling ``MultipeerTransceiver/invite(_:with:timeout:completion:)``.
public typealias InvitationCompletionHandler = (_ result: Result<Peer, Error>) -> Void

public struct MultipeerError: LocalizedError {
    public var localizedDescription: String

    public init(localizedDescription: String) {
        self.localizedDescription = localizedDescription
    }
}

final class MultipeerConnection: MultipeerProtocol {

    enum Mode: Int, CaseIterable {
        case receiver
        case transmitter
    }

    private let log = MultipeerKit.log(for: MultipeerConnection.self)

    let modes: [Mode]
    let configuration: MultipeerConfiguration
    let me: LocalPeerIdentity

    private let queue = DispatchQueue(label: "codes.rambo.MultipeerKit.connection")

    private var browser: NWBrowser?
    private var listener: NWListener?

    /// All peers we currently know about (browsed or seen via incoming connection),
    /// keyed by their stable peer id.
    private var discoveredPeers: [String: Peer] = [:]

    /// Active connections (post-handshake or in-progress) keyed by peer id.
    private var connections: [String: PeerConnection] = [:]

    /// Incoming connections we've accepted from the listener but haven't yet
    /// received a hello frame for. They're indexed by `ObjectIdentifier` because
    /// the peer id is not known until the hello frame arrives.
    private var pendingIncomingConnections: [ObjectIdentifier: PeerConnection] = [:]

    /// Completion handlers for manually-issued invites, keyed by peer id.
    private var invitationCompletions: [String: InvitationCompletionHandler] = [:]

    var didReceiveData: ((Data, Peer) -> Void)?
    var didFindPeer: ((Peer) -> Void)?
    var didLosePeer: ((Peer) -> Void)?
    var didConnectToPeer: ((Peer) -> Void)?
    var didDisconnectFromPeer: ((Peer) -> Void)?

    init(modes: [Mode] = Mode.allCases, configuration: MultipeerConfiguration = .default) {
        self.modes = modes
        self.configuration = configuration
        self.me = LocalPeerIdentity.fetchOrCreate(with: configuration)
    }

    // MARK: - Lifecycle

    func resume() {
        os_log("%{public}@", log: log, type: .debug, #function)

        let serviceType = bonjourServiceType

        queue.async { [weak self] in
            guard let self = self else { return }
            if self.modes.contains(.receiver) {
                self.startListener(serviceType: serviceType)
            }
            if self.modes.contains(.transmitter) {
                self.startBrowser(serviceType: serviceType)
            }
        }
    }

    func stop() {
        os_log("%{public}@", log: log, type: .debug, #function)

        queue.async { [weak self] in
            guard let self = self else { return }

            self.listener?.cancel()
            self.listener = nil
            self.browser?.cancel()
            self.browser = nil

            for (_, conn) in self.connections { conn.cancel() }
            self.connections.removeAll()

            for (_, conn) in self.pendingIncomingConnections { conn.cancel() }
            self.pendingIncomingConnections.removeAll()

            self.discoveredPeers.removeAll()
            self.invitationCompletions.removeAll()
        }
    }

    private var bonjourServiceType: String {
        "_\(configuration.serviceType)._tcp"
    }

    // MARK: - Networking parameters

    private func makeParameters() -> NWParameters {
        let parameters: NWParameters

        switch configuration.security.encryptionPreference {
        case .none:
            parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        default:
            // Covers both .required and the deprecated .optional, which the
            // Network framework cannot honour distinctly.
            parameters = NWParameters(tls: makeTLSOptions(), tcp: NWProtocolTCP.Options())
        }

        parameters.includePeerToPeer = true
        return parameters
    }

    private func makeTLSOptions() -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()

        if let identity = configuration.security.identity,
           let secIdentity = sec_identity_create(identity)
        {
            sec_protocol_options_set_local_identity(options.securityProtocolOptions, secIdentity)
        } else {
            os_log("encryptionPreference is .required but no SecIdentity was provided in MultipeerConfiguration.Security.identity. TLS handshakes will fail; set an identity or use .none encryption.",
                   log: log,
                   type: .fault)
        }

        return options
    }

    // MARK: - Listener (advertiser)

    private func startListener(serviceType: String) {
        do {
            let listener = try NWListener(using: makeParameters())

            let txt = NWTXTRecord([
                "peer-id": me.id,
                "peer-name": me.name
            ])

            listener.service = NWListener.Service(name: me.id, type: serviceType, txtRecord: txt)

            listener.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                if case .failed(let error) = state {
                    os_log("Listener failed to start. Make sure your app's Info.plist contains NSLocalNetworkUsageDescription and NSBonjourServices entries. Error: %{public}@",
                           log: self.log,
                           type: .fault,
                           String(describing: error))
                }
            }

            listener.newConnectionHandler = { [weak self] nwConn in
                self?.handleIncomingConnection(nwConn)
            }

            self.listener = listener
            listener.start(queue: queue)
        } catch {
            os_log("Failed to create listener: %{public}@", log: log, type: .fault, String(describing: error))
        }
    }

    private func handleIncomingConnection(_ nwConn: NWConnection) {
        let conn = PeerConnection(connection: nwConn, isInitiator: false, queue: queue, log: log)
        let key = ObjectIdentifier(conn)
        pendingIncomingConnections[key] = conn

        conn.didReceiveHello = { [weak self, weak conn] hello in
            guard let self = self, let conn = conn else { return }
            self.handleHelloReceived(on: conn, hello: hello)
        }

        conn.didDisconnect = { [weak self, weak conn] in
            guard let self = self, let conn = conn else { return }
            self.pendingIncomingConnections[key] = nil
            if let peerID = conn.peer?.id {
                self.handleConnectionLost(peerID: peerID, connection: conn)
            }
        }

        conn.didReceiveData = { [weak self, weak conn] data in
            guard let self = self, let conn = conn, let peer = conn.peer else { return }
            self.didReceiveData?(data, peer)
        }

        conn.start()
    }

    private func handleHelloReceived(on conn: PeerConnection, hello: HandshakeMessage) {
        let peer = Peer(id: hello.id, name: hello.name, discoveryInfo: hello.discoveryInfo, endpoint: nil, isConnected: false)
        conn.peer = peer

        if discoveredPeers[hello.id] == nil {
            discoveredPeers[hello.id] = peer
            didFindPeer?(peer)
        }

        // Simultaneous-connect resolution: when both peers discover each other
        // at the same time, both invite, and each side ends up with both an
        // outgoing connection (in `connections`) and an incoming one (in
        // `pendingIncomingConnections`). To keep both sides agreeing on the
        // same physical link, the connection initiated by the peer with the
        // lexicographically smaller id wins.
        if let existing = connections[hello.id], existing !== conn {
            let shouldKeepExisting: Bool
            if existing.isInitiator {
                shouldKeepExisting = me.id < hello.id
            } else {
                shouldKeepExisting = true
            }

            if shouldKeepExisting {
                conn.sendReject()
                conn.cancel()
                pendingIncomingConnections[ObjectIdentifier(conn)] = nil
                return
            } else {
                existing.cancel()
                connections[hello.id] = nil
            }
        }

        configuration.security.invitationHandler(peer, hello.context, { [weak self, weak conn] decision in
            guard let self = self else { return }
            self.queue.async {
                guard let conn = conn else { return }
                let key = ObjectIdentifier(conn)

                if decision {
                    conn.sendAccept()
                    self.pendingIncomingConnections[key] = nil
                    self.connections[peer.id] = conn
                    self.markConnected(peer.id)
                } else {
                    conn.sendReject()
                    conn.cancel()
                    self.pendingIncomingConnections[key] = nil
                }
            }
        })
    }

    // MARK: - Browser

    private func startBrowser(serviceType: String) {
        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(type: serviceType, domain: nil)
        let browser = NWBrowser(for: descriptor, using: makeParameters())

        browser.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            if case .failed(let error) = state {
                os_log("Browser failed to start. Make sure your app's Info.plist contains NSLocalNetworkUsageDescription and NSBonjourServices entries. Error: %{public}@",
                       log: self.log,
                       type: .fault,
                       String(describing: error))
            }
        }

        browser.browseResultsChangedHandler = { [weak self] _, changes in
            guard let self = self else { return }
            for change in changes {
                switch change {
                case .added(let result):
                    self.handleBrowserAdded(result)
                case .removed(let result):
                    self.handleBrowserRemoved(result)
                case .changed(_, let new, _):
                    self.handleBrowserAdded(new)
                case .identical:
                    break
                @unknown default:
                    break
                }
            }
        }

        self.browser = browser
        browser.start(queue: queue)
    }

    private func handleBrowserAdded(_ result: NWBrowser.Result) {
        guard let info = parseTXT(result.metadata) else {
            os_log("Discovered result without expected TXT record, ignoring", log: log, type: .debug)
            return
        }
        // Ignore our own advertisement.
        guard info.id != me.id else { return }

        let peer = Peer(id: info.id,
                        name: info.name,
                        discoveryInfo: info.extra,
                        endpoint: result.endpoint,
                        isConnected: discoveredPeers[info.id]?.isConnected ?? false)

        let isNew = discoveredPeers[info.id] == nil
        discoveredPeers[info.id] = peer

        if isNew {
            didFindPeer?(peer)
        }

        // Don't auto-initiate if we already have a live or in-flight connection.
        guard connections[info.id] == nil else { return }

        switch configuration.invitation {
        case .automatic:
            initiateConnection(to: peer, context: nil, timeout: 10.0)
        case .custom(let inviter):
            do {
                if let invite = try inviter(peer) {
                    initiateConnection(to: peer, context: invite.context, timeout: invite.timeout)
                } else {
                    os_log("Custom invite handler chose not to invite peer %{public}@", log: log, type: .debug, peer.name)
                }
            } catch {
                os_log("Custom invite handler threw: %{public}@", log: log, type: .error, String(describing: error))
            }
        case .none:
            os_log("Auto-invite disabled", log: log, type: .debug)
        }
    }

    private func handleBrowserRemoved(_ result: NWBrowser.Result) {
        guard let info = parseTXT(result.metadata) else { return }
        guard let peer = discoveredPeers[info.id] else { return }

        if let conn = connections[info.id] {
            conn.cancel()
            connections[info.id] = nil
        }

        discoveredPeers[info.id] = nil
        didLosePeer?(peer)
    }

    private func parseTXT(_ metadata: NWBrowser.Result.Metadata) -> (id: String, name: String, extra: [String: String]?)? {
        guard case .bonjour(let record) = metadata else { return nil }

        var id: String?
        var name: String?
        var extra: [String: String] = [:]

        for (key, value) in record {
            guard case .string(let stringValue) = value else { continue }
            switch key {
            case "peer-id": id = stringValue
            case "peer-name": name = stringValue
            default: extra[key] = stringValue
            }
        }

        guard let id = id, let name = name else { return nil }
        return (id, name, extra.isEmpty ? nil : extra)
    }

    // MARK: - Outbound connections

    private func initiateConnection(to peer: Peer, context: Data?, timeout: TimeInterval) {
        guard let endpoint = peer.endpoint else {
            os_log("Cannot initiate connection to peer %{public}@ without an endpoint", log: log, type: .error, peer.name)
            if let completion = invitationCompletions[peer.id] {
                completion(.failure(MultipeerError(localizedDescription: "Peer endpoint not known.")))
                invitationCompletions[peer.id] = nil
            }
            return
        }
        guard connections[peer.id] == nil else { return }

        let nwConn = NWConnection(to: endpoint, using: makeParameters())
        let conn = PeerConnection(connection: nwConn, isInitiator: true, queue: queue, log: log)
        conn.peer = peer
        connections[peer.id] = conn

        let helloPayload = HandshakeMessage(id: me.id, name: me.name, discoveryInfo: nil, context: context)

        conn.didBecomeReady = { [weak conn] in
            conn?.sendHello(helloPayload)
        }

        conn.didReceiveAccept = { [weak self] in
            self?.handleInvitationAccepted(peerID: peer.id)
        }

        conn.didReceiveReject = { [weak self] in
            self?.handleInvitationRejected(peerID: peer.id)
        }

        conn.didReceiveData = { [weak self, weak conn] data in
            guard let self = self, let conn = conn, let peer = conn.peer else { return }
            self.didReceiveData?(data, peer)
        }

        conn.didDisconnect = { [weak self, weak conn] in
            guard let self = self, let conn = conn else { return }
            self.handleConnectionLost(peerID: peer.id, connection: conn)
        }

        conn.start()

        queue.asyncAfter(deadline: .now() + timeout) { [weak self, weak conn] in
            guard let self = self, let conn = conn else { return }
            guard !conn.isHandshakeComplete else { return }

            os_log("Invitation to peer %{public}@ timed out", log: self.log, type: .error, peer.name)
            conn.cancel()
            self.connections[peer.id] = nil

            if let completion = self.invitationCompletions.removeValue(forKey: peer.id) {
                completion(.failure(MultipeerError(localizedDescription: "Invitation timed out.")))
            }
        }
    }

    private func handleInvitationAccepted(peerID: String) {
        markConnected(peerID)

        if let completion = invitationCompletions.removeValue(forKey: peerID),
           let peer = discoveredPeers[peerID]
        {
            completion(.success(peer))
        }
    }

    private func handleInvitationRejected(peerID: String) {
        if let conn = connections.removeValue(forKey: peerID) {
            conn.cancel()
        }

        if let completion = invitationCompletions.removeValue(forKey: peerID) {
            completion(.failure(MultipeerError(localizedDescription: "Invitation rejected.")))
        }
    }

    private func handleConnectionLost(peerID: String, connection: PeerConnection) {
        // Only react if the connection that disconnected is still the one we
        // consider "live" for this peer. Otherwise this is a leftover from
        // simultaneous-connect resolution and should be ignored.
        guard connections[peerID] === connection else { return }

        connections[peerID] = nil

        guard var peer = discoveredPeers[peerID] else { return }

        if peer.isConnected {
            peer.isConnected = false
            discoveredPeers[peerID] = peer
            didDisconnectFromPeer?(peer)
        }
    }

    private func markConnected(_ peerID: String) {
        guard var peer = discoveredPeers[peerID] else { return }
        guard !peer.isConnected else { return }

        peer.isConnected = true
        discoveredPeers[peerID] = peer
        didConnectToPeer?(peer)
    }

    // MARK: - Sending

    func broadcast(_ data: Data) throws {
        queue.async { [weak self] in
            guard let self = self else { return }

            let active = self.connections.values.filter { $0.isHandshakeComplete }
            guard !active.isEmpty else {
                os_log("Not broadcasting message: no connected peers", log: self.log, type: .error)
                return
            }

            for conn in active {
                conn.sendData(data)
            }
        }
    }

    func send(_ data: Data, to peers: [Peer]) throws {
        queue.async { [weak self] in
            guard let self = self else { return }
            for peer in peers {
                guard let conn = self.connections[peer.id], conn.isHandshakeComplete else { continue }
                conn.sendData(data)
            }
        }
    }

    // MARK: - Public API

    func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?) {
        queue.async { [weak self] in
            guard let self = self else { return }

            if let completion = completion {
                self.invitationCompletions[peer.id] = completion
            }

            let target = self.discoveredPeers[peer.id] ?? peer
            self.initiateConnection(to: target, context: context, timeout: timeout)
        }
    }

    func getLocalPeer() -> Peer? {
        return Peer(id: me.id, name: me.name, discoveryInfo: nil, endpoint: nil, isConnected: true)
    }

}
