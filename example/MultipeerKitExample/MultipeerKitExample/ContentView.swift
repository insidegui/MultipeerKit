import SwiftUI
import MultipeerKit

struct ContentView: View {
    @Environment(ChatStore.self) private var store

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            PeerListView(selection: $store.selectedPeerID)
                .navigationTitle("MultipeerKit")
        } detail: {
            if let peer = store.peer(forID: store.selectedPeerID) {
                ChatView(peerID: peer.id)
            } else {
                ContentUnavailableView(
                    "Pick a peer to start chatting",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Nearby devices running the app will appear in the sidebar.")
                )
            }
        }
    }
}

// MARK: - Peer list

private struct PeerListView: View {
    @Environment(ChatStore.self) private var store
    @Binding var selection: String?

    var body: some View {
        Group {
            if store.availablePeers.isEmpty {
                ContentUnavailableView(
                    "Looking for peers…",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Make sure the other device is on the same Wi-Fi network and has the app open.")
                )
            } else {
                List(selection: $selection) {
                    Section("Nearby") {
                        ForEach(store.availablePeers) { peer in
                            PeerRow(peer: peer)
                                .tag(peer.id)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let me = store.localPeer {
                LocalPeerFooter(peer: me)
            }
        }
    }
}

private struct PeerRow: View {
    let peer: Peer

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(peer.isConnected ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(peer.name)
                    .font(.body)
                Text(peer.isConnected ? "Connected" : "Available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct LocalPeerFooter: View {
    let peer: Peer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 0) {
                Text("You")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(peer.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

// MARK: - Chat

private struct ChatView: View {
    let peerID: String

    @Environment(ChatStore.self) private var store
    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    private var peer: Peer? { store.peer(forID: peerID) }
    private var messages: [ChatMessage] { store.messages(for: peerID) }

    var body: some View {
        if let peer {
            VStack(spacing: 0) {
                messagesScroll
                Divider()
                composer(peer: peer)
            }
            .navigationTitle(peer.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ConnectionBadge(isConnected: peer.isConnected)
                }
            }
        } else {
            ContentUnavailableView(
                "Peer no longer available",
                systemImage: "antenna.radiowaves.left.and.right.slash",
                description: Text("The selected peer is no longer in range.")
            )
        }
    }

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.move(edge: message.direction == .outgoing ? .trailing : .leading).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if messages.isEmpty {
                    ContentUnavailableView(
                        "No messages yet",
                        systemImage: "bubble.right",
                        description: Text("Say hi 👋")
                    )
                    .allowsHitTesting(false)
                }
            }
            .onAppear { scrollToLast(in: proxy, animated: false) }
            .onChange(of: messages.count) { _, _ in
                scrollToLast(in: proxy, animated: true)
            }
        }
    }

    private func composer(peer: Peer) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(!canSend(to: peer))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func canSend(to peer: Peer) -> Bool {
        peer.isConnected && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard let peer else { return }
        let body = draft
        draft = ""
        store.send(body, to: peer)
    }

    private func scrollToLast(in proxy: ScrollViewProxy, animated: Bool) {
        guard let last = messages.last else { return }
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

// MARK: - Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(spacing: 0) {
            if message.direction == .outgoing { Spacer(minLength: 48) }

            VStack(alignment: message.direction == .outgoing ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .foregroundStyle(message.direction == .outgoing ? .white : .primary)
                    .background(bubbleBackground, in: bubbleShape)

                Text(message.sentAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }

            if message.direction == .incoming { Spacer(minLength: 48) }
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        let big: CGFloat = 18
        let small: CGFloat = 4
        return UnevenRoundedRectangle(
            topLeadingRadius: big,
            bottomLeadingRadius: message.direction == .incoming ? small : big,
            bottomTrailingRadius: message.direction == .outgoing ? small : big,
            topTrailingRadius: big,
            style: .continuous
        )
    }

    private var bubbleBackground: AnyShapeStyle {
        switch message.direction {
        case .outgoing:
            return AnyShapeStyle(Color.accentColor.gradient)
        case .incoming:
            return AnyShapeStyle(Color(.secondarySystemBackground))
        }
    }
}

private struct ConnectionBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Connecting…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }
}
