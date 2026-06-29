import Foundation
import Network
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
final class PeerConnection {

    enum FrameType: UInt8 {
        case hello = 0x01
        case accept = 0x02
        case reject = 0x03
        case data = 0x04
    }

    private static let headerSize = 5
    private static let maxFramePayload = 8 * 1024 * 1024

    let connection: NWConnection
    let isInitiator: Bool
    let queue: DispatchQueue
    let log: OSLog

    /// The peer this connection is associated with. The initiator side knows
    /// this up-front from browser discovery; the receiver side learns it from
    /// the incoming hello frame.
    var peer: Peer?

    /// `true` once both sides have agreed on the invitation and are ready to
    /// exchange data frames.
    private(set) var isHandshakeComplete = false

    var didBecomeReady: (() -> Void)?
    var didReceiveHello: ((HandshakeMessage) -> Void)?
    var didReceiveAccept: (() -> Void)?
    var didReceiveReject: (() -> Void)?
    var didReceiveData: ((Data) -> Void)?
    var didDisconnect: (() -> Void)?

    private var receiveBuffer = Data()
    private var hasNotifiedDisconnect = false

    init(connection: NWConnection,
         isInitiator: Bool,
         queue: DispatchQueue,
         log: OSLog)
    {
        self.connection = connection
        self.isInitiator = isInitiator
        self.queue = queue
        self.log = log
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.didBecomeReady?()
                self.startReceive()
            case .failed(let error):
                os_log("Connection failed: %{public}@", log: self.log, type: .error, String(describing: error))
                self.notifyDisconnect()
            case .cancelled:
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
            isHandshakeComplete = true
            didReceiveAccept?()
        case .reject:
            didReceiveReject?()
        case .data:
            guard isHandshakeComplete else {
                os_log("Received data frame before handshake completed", log: log, type: .error)
                return
            }
            didReceiveData?(payload)
        }
    }

    func sendHello(_ hello: HandshakeMessage) {
        guard let data = try? JSONEncoder().encode(hello) else {
            os_log("Failed to encode hello frame", log: log, type: .error)
            return
        }
        sendFrame(type: .hello, payload: data)
    }

    func sendAccept() {
        isHandshakeComplete = true
        sendFrame(type: .accept, payload: Data())
    }

    func sendReject() {
        sendFrame(type: .reject, payload: Data())
    }

    func sendData(_ data: Data) {
        sendFrame(type: .data, payload: data)
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
