import Foundation

typealias PeerName = String

protocol MultipeerProtocol: AnyObject {

    var didReceiveData: ((Data, Peer) -> Void)? { get set }
    var didFindPeer: ((Peer) -> Void)? { get set }
    var didLosePeer: ((Peer) -> Void)? { get set }
    var didConnectToPeer: ((Peer) -> Void)? { get set }
    var didDisconnectFromPeer: ((Peer) -> Void)? { get set }

    func resume(with discoveryInfo: [String: String]?)
    func stop()

    func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?)
    func broadcast(_ data: Data) throws
    func send(_ data: Data, to peers: [Peer]) throws
    
    func getLocalPeerId() -> String?
    
    func fetchConnectionData(for peer: Peer, completion: @escaping (Result<Data, Error>) -> Void)
    func connectPeer(_ peer: Peer, using connectionData: Data)
    
}
