import SwiftUI
import MultipeerKit

struct ExamplesScreen: View {
    @EnvironmentObject private var dataSource: MultipeerDataSource
    @StateObject var peer: MultipeerDataSource.ObservablePeer

    var body: some View {
        TabView {
            ChatScreen(transceiver: dataSource.transceiver, peer: peer.observedPeer)
                .tabItem {
                    Label("Chat", systemImage: "bubble.fill")
                }
            Group {
                if #available(iOS 17.0, *) {
                    AirDropScreen(transceiver: dataSource.transceiver, peer: peer.observedPeer)
                } else {
                    Text("This demo requires iOS 17 or later.")
                        .foregroundStyle(.secondary)
                        .navigationTitle(Text("AirDrop"))
                }
            }
                .tabItem {
                    Label("AirDrop", systemImage: "dot.radiowaves.right")
                }
        }
        .navigationTitle(Text(peer.name))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                PeerStateIndicator(peer: peer)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExamplesScreen(peer: .mock)
    }
        .environmentObject(MultipeerDataSource.example)
}
