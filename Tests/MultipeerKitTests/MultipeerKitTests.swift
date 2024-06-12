import XCTest
@testable import MultipeerKit

fileprivate extension MultipeerTransceiver {
    var mockConnection: MockMultipeerConnection {
        connection as! MockMultipeerConnection
    }
}

fileprivate struct TestPayload: Hashable, Codable {
    let n: Int
}

final class MultipeerKitTests: XCTestCase {

    private func makeMockTransceiver() -> MultipeerTransceiver {
        MultipeerTransceiver(connection: MockMultipeerConnection())
    }

    func testCallingResumeResumesConnection() {
        let mock = makeMockTransceiver()
        mock.resume()
        XCTAssertEqual(mock.mockConnection.isRunning, true)
    }

    func testCallingStopStopsConnection() {
        let mock = makeMockTransceiver()
        mock.resume()
        mock.stop()
        XCTAssertEqual(mock.mockConnection.isRunning, false)
    }

    func testReceivingCustomPayload() {
        let mock = makeMockTransceiver()
        let tsPayload = TestPayload(n: 42)

        let expect = XCTestExpectation(description: "Receive payload")

        mock.receive(TestPayload.self) { payload, sender in
            XCTAssertEqual(payload, tsPayload)
            XCTAssertEqual(sender.id, mock.localPeer!.id)
            XCTAssertEqual(sender.id, mock.localPeerId!)

            expect.fulfill()
        }

        mock.broadcast(tsPayload)

        wait(for: [expect], timeout: 2)
    }
    
    @available(tvOS 13.0, *)
    @available(iOS 13.0, *)
    @available(macOS 10.15, *)
    func testAsyncEventsStreamContinuesWithEachPeerEvent() throws {
        let transceiver = makeMockTransceiver()
        transceiver.resume()
        
        let exp = expectation(description: "Async Peer")
        exp.expectedFulfillmentCount = 4
        
        Task.detached {
            // Used to ensure that events are yielded in the right order.
            var currentEvent = 0
            
            for await event in transceiver.peerEvents {
                switch event {
                case .found(let peer):
                    XCTAssertEqual(peer.id, "A")
                    XCTAssertEqual(currentEvent, 0)
                case .connected(let peer):
                    XCTAssertEqual(peer.id, "A")
                    XCTAssertEqual(currentEvent, 1)
                case .disconnected(let peer):
                    XCTAssertEqual(peer.id, "A")
                    XCTAssertEqual(currentEvent, 2)
                case .lost(let peer):
                    XCTAssertEqual(peer.id, "A")
                    XCTAssertEqual(currentEvent, 3)
                }
                
                currentEvent += 1
                exp.fulfill()
            }
        }
        
        let peer = transceiver.mockConnection.findFakePeer(with: "A")
        transceiver.mockConnection.connectFakePeer(peer)
        transceiver.mockConnection.disconnectFakePeer(peer)
        transceiver.mockConnection.loseFakePeer(peer)
        
        wait(for: [exp], timeout: 2)
    }

}
