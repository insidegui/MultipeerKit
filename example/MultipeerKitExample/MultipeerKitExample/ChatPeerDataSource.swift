//
//  ChatPeerDataSource.swift
//  MultipeerKitExample
//

import Foundation
import MultipeerKit

public struct ChatPeer: Hashable, Identifiable {
    public var id: String { peer.id }
    let peer: Peer
    var history: [String]
}

public final class ChatPeerDataSource: ObservableObject {
    
    private let transceiver: MultipeerTransceiver
    
    public init(transceiver: MultipeerTransceiver) {
        self.transceiver = transceiver
        
        transceiver.availablePeersDidChange = { [weak self] peers in
            guard let self = self else { return }

            self.availablePeers = peers.map { peer in
                if let resultPeer = self.availablePeers.first(where: { $0.peer == peer }) {
                    return resultPeer
                }
                else {
                    return ChatPeer(peer: peer, history: [])
                }
                
            }
        }
        
        availablePeers = transceiver.availablePeers.map { ChatPeer(peer: $0, history: []) }
    }
    
    @Published public private(set) var availablePeers: [ChatPeer] = []
    
    func send(_ message: String, to peers: [ChatPeer]) {
        let payload = ExamplePayload(message: message)
        transceiver.send(payload, to: peers.map { $0.peer })

        availablePeers = availablePeers.map { chatPeer in
            if var resultPeer = availablePeers.first(where: { $0.peer == chatPeer.peer }) {
                resultPeer.history.append(message)
                return resultPeer
            }
            else {
                return chatPeer
            }
            
        }
    }
}
