import Foundation
import MultipeerConnectivity.MCPeerID
import os.log

/// Handles all aspects related to the multipeer communication.
public final class MultipeerTransceiver {

    /// Represents events that occur when the local peer is receiving a resource from a remote peer.
    ///  
    /// When a remote peer uploads a file resource to the local peer via ``MultipeerTransceiver/send(_:to:)-592bk``,
    /// the local peer receives a callback registered using ``MultipeerTransceiver/receiveResources(using:)``.
    ///  
    /// The callback's argument is a stream of events reporting the resource download progress, then eventually
    /// a download completion with either the local URL to the file sent by the remote peer, or an error if the transfer has failed.
    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    public enum ResourceDownloadEvent {
        /// The resource transfer is in progress.
        ///
        /// The first associated value is the name of the file being uploaded to the local peer from the remote peer,
        /// the second associated value is a percentage from `0.0` to `1.0`.
        case progress(_ resourceName: String, _ progress: Double)
        /// The resource transfer has completed.
        ///
        /// The associated value is a result with either the URL to the local file that was transferred from the remote peer,
        /// or an error if the transfer has failed.
        case completion(Result<URL, Error>)
    }

    private let log = MultipeerKit.log(for: MultipeerTransceiver.self)

    let connection: MultipeerProtocol

    /// Called on the main queue when available peers have changed (new peers discovered or peers removed).
    public var availablePeersDidChange: ([Peer]) -> Void = { _ in }

    /// Called on the main queue when a new peer discovered.
    public var peerAdded: (Peer) -> Void = { _ in }

    /// Called on the main queue when a peer removed.
    public var peerRemoved: (Peer) -> Void = { _ in }

    /// Called on the main queue when a connection is established with a peer.
    public var peerConnected: (Peer) -> Void = { _ in }
    
    /// Called on the main queue when the connection with a peer is interrupted.
    public var peerDisconnected: (Peer) -> Void = { _ in }

    /// An `AsyncStream` of ``MultipeerTransceiver/ResourceDownloadEvent``.
    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    public typealias ResourceEventStream = AsyncStream<ResourceDownloadEvent>

    /// Handles remote resource uploads to the local peer. Registered via ``receiveResources(using:)``.
    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    public typealias ResourceEventHandler = (ResourceEventStream) -> Void

    /// The current device's peer id
    public var localPeer: Peer? {
        return connection.getLocalPeer()
    }

    @available(*, deprecated, renamed: "localPeer.id")
    public var localPeerId: String? {
        return localPeer?.id
    }

    /// All peers currently available for invitation, connection and data transmission.
    public private(set) var availablePeers: [Peer] = [] {
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

        if #available(iOS 13.0, tvOS 13.0, macOS 10.15, *) {
            connection.didStartReceivingResource = { [weak self] peer, resourceName, progress in
                DispatchQueue.main.async { self?.handleResourceReceiveStart(from: peer, resourceName: resourceName, progress: progress) }
            }
            connection.didFinishReceivingResource = { [weak self] peer, resourceName, result in
                DispatchQueue.main.async { self?.handleResourceReceiveFinished(from: peer, resourceName: resourceName, result: result) }
            }
        }
    }

    /// Configures a new handler for a specific `Codable` type.
    /// - Parameters:
    ///   - type: The `Codable` type to receive.
    ///   - closure: The closure that will be called whenever a payload of the specified type is received.
    ///   - payload: The payload decoded from the remote message.
    ///   - sender: The remote peer who sent the message.
    ///
    /// MultipeerKit communicates data between peers as JSON-encoded payloads which originate with
    /// `Codable` entities. You register a closure to handle each specific type of entity,
    /// and this closure is automatically called by the framework when a remote peer sends
    /// a message containing an entity that decodes to the specified type.
    public func receive<T: Codable>(_ type: T.Type, using closure: @escaping (_ payload: T, _ sender: Peer) -> Void) {
        MultipeerMessage.register(type, for: String(describing: type), closure: closure)
    }

    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    public func receiveResources(using closure: @escaping ResourceEventHandler) {
        assert(resourceEventHandler == nil, "Can't register more than one resource event receiver")

        resourceEventHandler = closure
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

    /// Sends a message to a specific set of peers.
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

    /// Uploads a file to the remote peer.
    /// - Parameters:
    ///   - resourceURL: URL to the local file that will be uploaded. Remote URLs are not supported.
    ///   - peer: The remote peer that will receive the uploaded file.
    /// - Returns: A stream that produces a new value for each change in upload progress.
    /// The stream throws if uploading fails, and terminates when the upload completes successfully.
    ///
    /// Use `for try await` syntax in order to get updates on the upload, example:
    ///
    /// ```swift
    /// let peer = ...
    /// let url = URL(filePath: ...)
    /// do {
    ///     for try await progress in transceiver.send(url, to: peer) {
    ///         print("Upload progress: \(progress)")
    ///     }
    ///
    ///     print("Upload finished")
    /// } catch {
    ///     print("Upload failed: \(error)")
    /// }
    /// ```
    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    public func send(_ resourceURL: URL, to peer: Peer) -> ResourceUploadStream {
        os_log("%{public}@", log: log, type: .debug, #function)

        return connection.send(resourceURL, to: peer)
    }

    private func handleDataReceived(_ data: Data, from peer: Peer) {
        os_log("%{public}@", log: log, type: .debug, #function)

        do {
            let decoder = JSONDecoder()
            decoder.userInfo[MultipeerMessage.senderUserInfoKey] = peer
            let message = try decoder.decode(MultipeerMessage.self, from: data)

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
        peerAdded(peer)
    }

    private func handlePeerRemoved(_ peer: Peer) {
        guard let idx = availablePeers.firstIndex(where: { $0.underlyingPeer == peer.underlyingPeer }) else { return }

        availablePeers.remove(at: idx)
        peerRemoved(peer)
    }

    private func handlePeerConnected(_ peer: Peer) {
        setConnected(true, on: peer)
        
        peerConnected(peer)
    }

    private func handlePeerDisconnected(_ peer: Peer) {
        setConnected(false, on: peer)
        
        peerDisconnected(peer)
    }

    private func setConnected(_ connected: Bool, on peer: Peer) {
        guard let idx = availablePeers.firstIndex(where: { $0.underlyingPeer == peer.underlyingPeer }) else { return }

        var mutablePeer = availablePeers[idx]
        mutablePeer.isConnected = connected
        availablePeers[idx] = mutablePeer
    }

    // MARK: - Resource Support

    /// Storage for `resourceEventHandler` because that must be 10.15 and up only,
    /// but stored properties can't have availability annotations.
    private var _resourceEventHandler: Any?

    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    private var resourceEventHandler: ResourceEventHandler? {
        get { _resourceEventHandler as? ResourceEventHandler }
        set { _resourceEventHandler = newValue }
    }

    /// Storage for `resourceContinuations`.
    private var _resourceContinuations: Any?

    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    private var resourceContinuations: [String: ResourceEventStream.Continuation] {
        get { _resourceContinuations as? [String: ResourceEventStream.Continuation] ?? [:] }
        set { _resourceContinuations = newValue }
    }

    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    private func handleResourceReceiveStart(from peer: Peer, resourceName: String, progress: Progress) {
        os_log("Start receiving resource %@ from %@", log: self.log, type: .debug, resourceName, peer.name)

        guard let resourceEventHandler else {
            os_log("Received a resource from remote peer, but you haven't configured the transceiver to receive resources. Make sure your app calls receiveResources() before sending a resource from a remote peer to the local peer.", log: self.log, type: .fault)
            assertionFailure("Received a resource from remote peer, but you haven't configured the transceiver to receive resources. Make sure your app calls receiveResources() before sending a resource from a remote peer to the local peer.")
            return
        }

        let (stream, continuation) = ResourceEventStream.makeStream()

        resourceEventHandler(stream)

        /// Yield an initial progress event with 0%
        continuation.yield(.progress(resourceName, 0))

        let cancellable = progress.publisher(for: \.fractionCompleted).sink { fraction in
            continuation.yield(.progress(resourceName, fraction))
        }

        continuation.onTermination = { @Sendable [weak self] _ in
            guard let self else { return }
            cancellable.cancel()
            resourceContinuations[resourceName] = nil
        }
    }

    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    private func handleResourceReceiveFinished(from peer: Peer, resourceName: String, result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            os_log("Finished receiving resource %@ from %@. Resource is at %@", log: self.log, type: .debug, resourceName, peer.name, url.path)
        case .failure(let error):
            os_log("Error receiving resource %@ from %@: %{public}@", log: self.log, type: .error, resourceName, peer.name, String(describing: error))
        }

        guard let continuation = resourceContinuations[resourceName] else {
            os_log("Received a resource finished event for %@, but couldn't find a continuation for reporting the completion!", log: self.log, type: .fault, resourceName)
            return
        }

        continuation.yield(.completion(result))
        continuation.finish()
    }

}
