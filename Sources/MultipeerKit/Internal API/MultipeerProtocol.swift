import Foundation

typealias PeerName = String

protocol MultipeerProtocol: AnyObject {

    var didReceiveData: ((Data, Peer) -> Void)? { get set }
    var didFindPeer: ((Peer) -> Void)? { get set }
    var didLosePeer: ((Peer) -> Void)? { get set }
    var didConnectToPeer: ((Peer) -> Void)? { get set }
    var didDisconnectFromPeer: ((Peer) -> Void)? { get set }
    var didStartReceivingResource: ((_ sender: Peer, _ resourceName: String, _ progress: Progress) -> Void)? { get set }
    var didFinishReceivingResource: ((_ sender: Peer, _ resourceName: String, _ result: Result<URL, Error>) -> Void)? { get set }

    func resume()
    func stop()

    func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?)
    func broadcast(_ data: Data) throws
    func send(_ data: Data, to peers: [Peer]) throws

    @available(iOS 13.0, macOS 10.15, *)
    func send(_ resourceURL: URL, to peer: Peer) -> ResourceUploadStream

    func getLocalPeer() -> Peer?

}
