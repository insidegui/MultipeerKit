import Foundation
import MultipeerConnectivity.MCPeerID

final class MockMultipeerConnection: MultipeerProtocol {

    let localPeer = Peer.mock

    var didReceiveData: ((Data, Peer) -> Void)?
    var didFindPeer: ((Peer) -> Void)?
    var didLosePeer: ((Peer) -> Void)?
    var didConnectToPeer: ((Peer) -> Void)?
    var didDisconnectFromPeer: ((Peer) -> Void)?
    var didStartReceivingResource: ((_ sender: Peer, _ resourceName: String, _ progress: Progress) -> Void)?
    var didFinishReceivingResource: ((_ sender: Peer, _ resourceName: String, _ result: Result<URL, Error>) -> Void)?

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

    @available(iOS 13.0, macOS 10.15, *)
    func send(_ resourceURL: URL, to peer: Peer) -> ResourceUploadStream {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?) {
        
    }
    
    func getLocalPeer() -> Peer? {
        return localPeer
    }

}
