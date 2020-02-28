import Foundation

typealias PeerName = String

protocol MultipeerProtocol: AnyObject {

    var didReceiveData: ((Data, PeerName) -> Void)? { get set }

    func resume()
    func stop()

    func broadcast(_ data: Data) throws

}
