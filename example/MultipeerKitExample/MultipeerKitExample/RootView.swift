import SwiftUI
import MultipeerKit

struct RootView: View {
    @EnvironmentObject var dataSource: MultipeerDataSource

    var body: some View {
        NavigationStack {
            PeerSelectionScreen()
                .navigationTitle(Text("MultipeerKit"))
                .navigationDestination(for: Peer.self) { peer in
                    ExamplesScreen(peer: dataSource.observablePeer(peer))
                        .navigationTitle(Text(peer.name))
                }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(MultipeerDataSource.example)
}
