import Foundation
import Network
import CryptoKit
import os.log

/// Wraps an `NWConnection` and applies MultipeerKit's wire framing.
///
/// The wire format is a stream of frames:
///
/// ```
/// [u8 frame_type][u32 big-endian payload_length][payload_length bytes payload]
/// ```
///
/// A new connection sends a `hello` frame first, then waits for an `accept`
/// or `reject` frame before either side starts exchanging `data` frames.
///
/// When `usesEncryption` is true, the handshake also performs an ephemeral
/// X25519 key agreement (initiator's public key in HELLO, responder's in
/// ACCEPT). Both sides HKDF-derive a session key and seal every subsequent
/// DATA frame with ChaCha20-Poly1305.
final class PeerConnection {

    enum FrameType: UInt8 {
        case hello = 0x01
        case accept = 0x02
        case reject = 0x03
        case data = 0x04
    }

    private static let headerSize = 5
    private static let maxFramePayload = 8 * 1024 * 1024
    private static let publicKeyByteCount = 32

    let connection: NWConnection
    let isInitiator: Bool
    let usesEncryption: Bool
    let queue: DispatchQueue
    let log: OSLog

    var peer: Peer?

    private(set) var isHandshakeComplete = false

    var didBecomeReady: (() -> Void)?
    var didReceiveHello: ((HandshakeMessage) -> Void)?
    var didReceiveAccept: (() -> Void)?
    var didReceiveReject: (() -> Void)?
    var didReceiveData: ((Data) -> Void)?
    var didDisconnect: (() -> Void)?

    private var receiveBuffer = Data()
    private var hasNotifiedDisconnect = false

    private var localKeyAgreement: Curve25519.KeyAgreement.PrivateKey?
    private var sessionKey: SymmetricKey?

    init(connection: NWConnection,
         isInitiator: Bool,
         usesEncryption: Bool,
         queue: DispatchQueue,
         log: OSLog)
    {
        self.connection = connection
        self.isInitiator = isInitiator
        self.usesEncryption = usesEncryption
        self.queue = queue
        self.log = log

        if usesEncryption {
            self.localKeyAgreement = Curve25519.KeyAgreement.PrivateKey()
        }
    }

    var localPublicKeyData: Data? {
        localKeyAgreement?.publicKey.rawRepresentation
    }

    /// Returns true if a shared session key was established (or if encryption
    /// is disabled and no key is needed).
    @discardableResult
    func deriveSessionKey(fromPeerPublicKey peerPublicKey: Data) -> Bool {
        guard usesEncryption else { return true }
        guard let local = localKeyAgreement else { return false }
        guard peerPublicKey.count == Self.publicKeyByteCount else {
            os_log("Peer ephemeral key has wrong length %d", log: log, type: .error, peerPublicKey.count)
            return false
        }

        do {
            let pub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
            let shared = try local.sharedSecretFromKeyAgreement(with: pub)
            sessionKey = shared.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data("codes.rambo.MultipeerKit.session.salt".utf8),
                sharedInfo: Data("codes.rambo.MultipeerKit.session.v1".utf8),
                outputByteCount: 32
            )
            return true
        } catch {
            os_log("Key agreement failed: %{public}@", log: log, type: .error, String(describing: error))
            return false
        }
    }

    func start() {
        let role = isInitiator ? "outgoing" : "incoming"
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .preparing:
                os_log("%{public}@ connection preparing", log: self.log, type: .debug, role)
            case .waiting(let error):
                os_log("%{public}@ connection waiting: %{public}@", log: self.log, type: .info, role, String(describing: error))
            case .ready:
                os_log("%{public}@ connection ready", log: self.log, type: .info, role)
                self.didBecomeReady?()
                self.startReceive()
            case .failed(let error):
                os_log("%{public}@ connection failed: %{public}@", log: self.log, type: .error, role, String(describing: error))
                self.notifyDisconnect()
            case .cancelled:
                os_log("%{public}@ connection cancelled", log: self.log, type: .debug, role)
                self.notifyDisconnect()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func cancel() {
        connection.cancel()
    }

    private func notifyDisconnect() {
        guard !hasNotifiedDisconnect else { return }
        hasNotifiedDisconnect = true
        didDisconnect?()
    }

    private func startReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.receiveBuffer.append(data)
                self.processBuffer()
            }

            if let error = error {
                os_log("Receive error: %{public}@", log: self.log, type: .error, String(describing: error))
                self.notifyDisconnect()
                return
            }

            if isComplete {
                self.notifyDisconnect()
                return
            }

            self.startReceive()
        }
    }

    private func processBuffer() {
        while receiveBuffer.count >= Self.headerSize {
            let typeByte = receiveBuffer[receiveBuffer.startIndex]
            let lengthSlice = receiveBuffer[(receiveBuffer.startIndex + 1)..<(receiveBuffer.startIndex + Self.headerSize)]

            var lengthBE: UInt32 = 0
            for byte in lengthSlice {
                lengthBE = (lengthBE << 8) | UInt32(byte)
            }
            let length = Int(lengthBE)

            if length > Self.maxFramePayload {
                os_log("Frame payload too large (%d bytes), closing connection", log: log, type: .error, length)
                cancel()
                return
            }

            guard receiveBuffer.count >= Self.headerSize + length else { break }

            let payloadStart = receiveBuffer.startIndex + Self.headerSize
            let payload = Data(receiveBuffer[payloadStart..<(payloadStart + length)])
            receiveBuffer.removeFirst(Self.headerSize + length)

            guard let type = FrameType(rawValue: typeByte) else {
                os_log("Unknown frame type: %d", log: log, type: .error, typeByte)
                continue
            }

            handleFrame(type, payload: payload)
        }
    }

    private func handleFrame(_ type: FrameType, payload: Data) {
        switch type {
        case .hello:
            guard let hello = try? JSONDecoder().decode(HandshakeMessage.self, from: payload) else {
                os_log("Failed to decode hello frame", log: log, type: .error)
                cancel()
                return
            }
            didReceiveHello?(hello)
        case .accept:
            if usesEncryption {
                guard payload.count == Self.publicKeyByteCount else {
                    os_log("ACCEPT frame missing ephemeral public key (got %d bytes)", log: log, type: .error, payload.count)
                    cancel()
                    return
                }
                guard deriveSessionKey(fromPeerPublicKey: payload) else {
                    cancel()
                    return
                }
            }
            isHandshakeComplete = true
            didReceiveAccept?()
        case .reject:
            didReceiveReject?()
        case .data:
            guard isHandshakeComplete else {
                os_log("Received data frame before handshake completed", log: log, type: .error)
                return
            }
            handleDataPayload(payload)
        }
    }

    private func handleDataPayload(_ payload: Data) {
        if let key = sessionKey {
            do {
                let sealed = try ChaChaPoly.SealedBox(combined: payload)
                let plaintext = try ChaChaPoly.open(sealed, using: key)
                didReceiveData?(plaintext)
            } catch {
                os_log("Failed to decrypt data frame: %{public}@", log: log, type: .error, String(describing: error))
            }
        } else {
            didReceiveData?(payload)
        }
    }

    // MARK: - Sending

    func sendHello(id: String, name: String, discoveryInfo: [String: String]?, context: Data?) {
        let message = HandshakeMessage(
            id: id,
            name: name,
            discoveryInfo: discoveryInfo,
            context: context,
            ephemeralPublicKey: usesEncryption ? localPublicKeyData : nil
        )
        guard let data = try? JSONEncoder().encode(message) else {
            os_log("Failed to encode hello frame", log: log, type: .error)
            return
        }
        sendFrame(type: .hello, payload: data)
    }

    func sendAccept() {
        isHandshakeComplete = true
        let payload = (usesEncryption ? localPublicKeyData : nil) ?? Data()
        sendFrame(type: .accept, payload: payload)
    }

    func sendReject() {
        sendFrame(type: .reject, payload: Data())
    }

    func sendData(_ data: Data) {
        let payload: Data
        if let key = sessionKey {
            do {
                let sealed = try ChaChaPoly.seal(data, using: key)
                payload = sealed.combined
            } catch {
                os_log("Failed to encrypt data frame: %{public}@", log: log, type: .error, String(describing: error))
                return
            }
        } else {
            payload = data
        }
        sendFrame(type: .data, payload: payload)
    }

    private func sendFrame(type: FrameType, payload: Data) {
        var packet = Data(capacity: Self.headerSize + payload.count)
        packet.append(type.rawValue)
        var lengthBE = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &lengthBE) { packet.append(contentsOf: $0) }
        packet.append(payload)

        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            if let error = error, let self = self {
                os_log("Send error: %{public}@", log: self.log, type: .error, String(describing: error))
            }
        })
    }
}
