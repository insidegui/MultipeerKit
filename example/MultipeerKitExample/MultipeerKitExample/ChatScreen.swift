import SwiftUI
import MultipeerKit
import Combine

struct ChatPayload: Codable {
    var message: String
}

final class ChatViewModel: ObservableObject {

    struct Message: Identifiable, Hashable {
        var id = UUID()
        var date = Date()
        var senderName: String
        var text: String
    }

    @Published private(set) var messages = [Message]()

    let transceiver: MultipeerTransceiver
    let remotePeer: Peer

    init(transceiver: MultipeerTransceiver, remotePeer: Peer) {
        self.transceiver = transceiver
        self.remotePeer = remotePeer

        transceiver.receive(ChatPayload.self) { [weak self] payload, sender in
            guard let self = self else { return }

            let message = Message(senderName: sender.name, text: payload.message)

            messages.insert(message, at: 0)
        }
    }

    func send(_ text: String) {
        let localMessage = Message(senderName: "You Sent", text: text)
        messages.insert(localMessage, at: 0)

        let payload = ChatPayload(message: text)
        transceiver.send(payload, to: [remotePeer])
    }

}

struct ChatScreen: View {
    @StateObject private var viewModel: ChatViewModel

    init(transceiver: MultipeerTransceiver, peer: Peer) {
        let viewModel = ChatViewModel(transceiver: transceiver, remotePeer: peer)
        self._viewModel = .init(wrappedValue: viewModel)
    }

    @State private var messageText = ""

    var body: some View {
        List(viewModel.messages) { message in
            VStack(alignment: .leading) {
                Text(message.senderName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                Text(message.text)
            }
                .listRowSeparator(.hidden)
        }
        .listStyle(.inset)
        .animation(.default, value: viewModel.messages.count)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading) {
                Text("Send Message")
                    .font(.headline)
                HStack {
                    TextField("Message", text: $messageText)
                        .onSubmit(send)
                        .textFieldStyle(.roundedBorder)
                    Button("Send", action: send)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Material.thick)
            .overlay(alignment: .top) { Divider() }
        }
        .navigationTitle(Text("Chat"))
    }

    private func send() {
        guard !messageText.isEmpty else { return }
        viewModel.send(messageText)
        messageText = ""
    }
}

#Preview {
    ChatScreen(transceiver: .example, peer: .mock)
}
