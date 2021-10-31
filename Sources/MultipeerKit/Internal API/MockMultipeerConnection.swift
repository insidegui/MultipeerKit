import Foundation
import MultipeerConnectivity.MCPeerID

final class MockMultipeerConnection: MultipeerProtocol {

    let localPeer: Peer = {
        let underlyingPeer = MCPeerID(displayName: "MockPeer")
        return try! Peer(peer: underlyingPeer, discoveryInfo: nil)
    }()

    var didReceiveData: ((Data, Peer) -> Void)?
    var didFindPeer: ((Peer) -> Void)?
    var didLosePeer: ((Peer) -> Void)?
    var didConnectToPeer: ((Peer) -> Void)?
    var didDisconnectFromPeer: ((Peer) -> Void)?
    
    var isRunning = false

    func resume() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func broadcast(_ data: Data) throws {
        didReceiveData?(data, localPeer)
    }

    func send(_ data: Data, to peers: [Peer]) throws {
        
    }

    func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?) {
        
    }
    
    func getLocalPeerId() -> String? {
        return localPeer.id
    }
    
    @discardableResult func findFakePeer(with id: String) -> Peer {
        let fakePeer = Peer(
            underlyingPeer: MCPeerID(displayName: id),
            id: id,
            name: id,
            discoveryInfo: nil,
            isConnected: false
        )
        
        didFindPeer?(fakePeer)
        
        return fakePeer
    }
    
    func loseFakePeer(_ fakePeer: Peer) {
        didLosePeer?(fakePeer)
    }
    
    func connectFakePeer(_ fakePeer: Peer) {
        didConnectToPeer?(fakePeer)
    }
    
    func disconnectFakePeer(_ fakePeer: Peer) {
        didDisconnectFromPeer?(fakePeer)
    }

}
