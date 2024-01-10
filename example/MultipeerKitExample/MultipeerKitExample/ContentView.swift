//
//  ContentView.swift
//  MultipeerKitExample
//
//  Created by Guilherme Rambo on 29/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import MultipeerKit
import Combine

final class ViewModel: ObservableObject {
    @Published var message: String = ""
    @Published var selectedPeers: [Peer] = []

    func toggle(_ peer: Peer) {
        if selectedPeers.contains(peer) {
            selectedPeers.remove(at: selectedPeers.firstIndex(of: peer)!)
        } else {
            selectedPeers.append(peer)
        }
    }
}

struct ContentView: View {
    @ObservedObject private(set) var viewModel = ViewModel()
    @EnvironmentObject var dataSource: MultipeerDataSource

    @State private var showErrorAlert = false

    var body: some View {
        VStack {
            Form {
                TextField("Message", text: $viewModel.message)

                Button(action: { self.sendToSelectedPeers(self.viewModel.message) }) {
                    Text("SEND")
                }
            }

            VStack(alignment: .leading) {
                Text("Peers").font(.system(.headline)).padding()

                List {
                    ForEach(dataSource.availablePeers) { peer in
                        HStack {
                            Circle()
                                .frame(width: 12, height: 12)
                                .foregroundColor(peer.isConnected ? .green : .gray)
                            
                            Text(peer.name)

                            Spacer()

                            if self.viewModel.selectedPeers.contains(peer) {
                                Image(systemName: "checkmark")
                            }
                        }.onTapGesture {
                            self.viewModel.toggle(peer)
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

        let payload = ExamplePayload(message: self.viewModel.message)
        do {
            try dataSource.transceiver.sendWithError(payload, to: viewModel.selectedPeers)
        } catch _ {
            showErrorAlert = true
        }
    }
}

