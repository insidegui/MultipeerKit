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

    func resume(with discoveryInfo: [String : String]?) {
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
    
    func fetchConnectionData(for peer: Peer, completion: @escaping (Result<Data, Error>) -> Void) {
        
    }
    
    func connectPeer(_ peer: Peer, using connectionData: Data) {
        
    }

}
