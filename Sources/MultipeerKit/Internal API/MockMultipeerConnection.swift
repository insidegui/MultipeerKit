import Foundation

final class MockMultipeerConnection: MultipeerProtocol {

    let localPeer: Peer = Peer(
        id: "mock-peer-id",
        name: "MockPeer",
        discoveryInfo: nil,
        endpoint: nil,
        isConnected: true
    )

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

    func getLocalPeer() -> Peer? {
        return localPeer
    }

}
