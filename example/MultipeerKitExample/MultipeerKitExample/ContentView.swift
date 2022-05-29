//
//  ContentView.swift
//  MultipeerKitExample
//
//  Created by Guilherme Rambo on 29/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import Combine

final class ViewModel: ObservableObject {
    @Published var message: String = ""
    @Published var selectedPeers: [ChatPeer] = []

    func toggle(_ chatPeer: ChatPeer) {
        if selectedPeers.contains(chatPeer) {
            selectedPeers.remove(at: selectedPeers.firstIndex(of: chatPeer)!)
        } else {
            selectedPeers.append(chatPeer)
        }
    }
}

struct ContentView: View {
    @ObservedObject private(set) var viewModel = ViewModel()
    @EnvironmentObject var dataSource: ChatPeerDataSource

    @State private var showErrorAlert = false

    var body: some View {
        VStack {
            Form {
                TextField("Message", text: $viewModel.message)

                Button(action: { self.sendToSelectedPeers(self.viewModel.message) }) {
                    Text("SEND")
                }

                Text("\(dataSource.availablePeers.reduce(0, { $0 + $1.history.count })) message(s) sent")
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading) {
                Text("Peers").font(.system(.headline)).padding()

                List {
                    ForEach(dataSource.availablePeers) { chatPeer in
                        HStack {
                            Circle()
                                .frame(width: 12, height: 12)
                                .foregroundColor(chatPeer.peer.isConnected ? .green : .gray)
                            
                            Text(chatPeer.peer.name)

                            Spacer()

                            if viewModel.selectedPeers.map({ $0.peer }).contains(chatPeer.peer) {
                                Image(systemName: "checkmark")
                            }
                        }.onTapGesture {
                            viewModel.toggle(chatPeer)
                        }
                    }
                }
            }
        }.alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Please select a peer"), message: nil, dismissButton: nil)
        }
    }

    func sendToSelectedPeers(_ message: String) {
        guard !self.viewModel.selectedPeers.isEmpty else {
            showErrorAlert = true
            return
        }

        dataSource.send(message, to: viewModel.selectedPeers)
    }
}

