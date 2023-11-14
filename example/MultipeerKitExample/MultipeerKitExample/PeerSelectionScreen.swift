import SwiftUI
import MultipeerKit

struct PeerSelectionScreen: View {
    @EnvironmentObject private var dataSource: MultipeerDataSource

    var body: some View {
        List{
            Section {
                ForEach(dataSource.availablePeers) { peer in
                    NavigationLink(value: peer) {
                        PeerListItem(peer: peer)
                    }
                }
            } footer: {
                Text("Choose a remote device to communicate with.")
            }
        }
        .overlay {
            if dataSource.availablePeers.isEmpty {
                ProgressOverlay(message: "Looking for peers")
            }
        }
        .animation(.default, value: dataSource.availablePeers.isEmpty)
    }
}

struct ProgressOverlay: View {
    var message: LocalizedStringKey
    
    var body: some View {
        VStack(spacing: 6) {
            ProgressView()
            Text(message)
                .foregroundStyle(.secondary)
                .font(.headline)
        }
        .transition(.scale(scale: 1.5).combined(with: .opacity))
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

struct PeerListItem: View {
    @EnvironmentObject private var dataSource: MultipeerDataSource
    var peer: Peer

    var body: some View {
        HStack {
            PeerStateIndicator(peer: dataSource.observablePeer(peer))

            Text(peer.name)
        }
    }
}

#Preview {
    PeerSelectionScreen()
        .environmentObject(MultipeerDataSource.example)
}
