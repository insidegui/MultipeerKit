import Foundation

final class MockMultipeerConnection: MultipeerProtocol {

    var didReceiveData: ((Data, PeerName) -> Void)?
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
        didReceiveData?(data, "MockPeer")
    }

    func send(_ data: Data, to peers: [Peer]) throws {
        
    }

    func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?) {
        
    }

}
