import SwiftUI
import MultipeerKit

struct PeerSelectionScreen: View {
    @EnvironmentObject private var dataSource: MultipeerDataSource

    var body: some View {
        List(dataSource.availablePeers) { peer in
            Section {
                NavigationLink(value: peer) {
                    HStack {
                        PeerStateIndicator(peer: dataSource.observablePeer(peer))

                        Text(peer.name)
                    }
                }
            } footer: {
                Text("Choose a remote device to communicate with.")
            }
        }
        .overlay {
            if dataSource.availablePeers.isEmpty {
                VStack(spacing: 6) {
                    ProgressView()
                    Text("Looking for peers")
                        .foregroundStyle(.secondary)
                        .font(.headline)
                }
                .transition(.scale(scale: 1.5).combined(with: .opacity))
            }
        }
        .animation(.default, value: dataSource.availablePeers.isEmpty)
    }
}

struct PeerStateIndicator: View {
    @StateObject var peer: ObservablePeer

    var body: some View {
        Circle()
            .fill(peer.isConnected ? .green : .gray)
            .frame(width: 8, height: 8)
    }
}

#Preview {
    PeerSelectionScreen()
        .environmentObject(MultipeerDataSource.example)
}
