import Foundation

typealias PeerName = String

protocol MultipeerProtocol: AnyObject {

    var didReceiveData: ((Data, PeerName) -> Void)? { get set }
    var didFindPeer: ((Peer) -> Void)? { get set }
    var didLosePeer: ((Peer) -> Void)? { get set }
    var didConnectToPeer: ((Peer) -> Void)? { get set }
    var didDisconnectFromPeer: ((Peer) -> Void)? { get set }

    func resume()
    func stop()

    func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?)
    func broadcast(_ data: Data) throws
    func send(_ data: Data, to peers: [Peer]) throws

}
