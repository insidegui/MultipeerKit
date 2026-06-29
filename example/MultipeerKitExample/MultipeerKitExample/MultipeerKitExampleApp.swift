import SwiftUI
import Observation
import UserNotifications
import MultipeerKit

@main
struct MultipeerKitExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

struct ChatMessage: Identifiable, Hashable {
    enum Direction { case outgoing, incoming }

    let id: UUID
    let body: String
    let sentAt: Date
    let direction: Direction
}

@Observable
final class ChatStore {

    private(set) var availablePeers: [Peer] = []
    private(set) var localPeer: Peer?
    private(set) var conversations: [String: [ChatMessage]] = [:]

    var selectedPeerID: String?

    let transceiver: MultipeerTransceiver

    init() {
        var config = MultipeerConfiguration.default
        config.serviceType = "MPKitDemo"
        // No SecIdentity supplied — MultipeerKit will use TLS 1.3 with an
        // ephemeral PSK derived from the service type.
        config.security.encryptionPreference = .required

        let t = MultipeerTransceiver(configuration: config)
        self.transceiver = t

        t.availablePeersDidChange = { [weak self] peers in
            self?.availablePeers = peers
        }
        t.receive(ExamplePayload.self) { [weak self] payload, sender in
            self?.handle(payload, from: sender)
        }

        self.localPeer = t.localPeer
        t.resume()
    }

    func messages(for peerID: String) -> [ChatMessage] {
        conversations[peerID] ?? []
    }

    func peer(forID id: String?) -> Peer? {
        guard let id else { return nil }
        return availablePeers.first { $0.id == id }
    }

    func send(_ body: String, to peer: Peer) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let payload = ExamplePayload(id: UUID(), body: trimmed, sentAt: Date())
        transceiver.send(payload, to: [peer])

        append(
            ChatMessage(id: payload.id,
                        body: payload.body,
                        sentAt: payload.sentAt,
                        direction: .outgoing),
            to: peer.id
        )
    }

    private func handle(_ payload: ExamplePayload, from peer: Peer) {
        append(
            ChatMessage(id: payload.id,
                        body: payload.body,
                        sentAt: payload.sentAt,
                        direction: .incoming),
            to: peer.id
        )
        notifyIncoming(payload, from: peer)
    }

    private func append(_ message: ChatMessage, to peerID: String) {
        var bucket = conversations[peerID] ?? []
        bucket.append(message)
        conversations[peerID] = bucket
    }

    private func notifyIncoming(_ payload: ExamplePayload, from peer: Peer) {
        // Only post a notification when the user isn't currently looking at
        // this conversation.
        guard selectedPeerID != peer.id else { return }

        let content = UNMutableNotificationContent()
        content.title = peer.name
        content.body = payload.body
        let request = UNNotificationRequest(identifier: payload.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
