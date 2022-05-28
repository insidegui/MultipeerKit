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

    static var allTests = [
        ("testCallingResumeResumesConnection", testCallingResumeResumesConnection),
        ("testCallingStopStopsConnection", testCallingStopStopsConnection),
        ("testReceivingCustomPayload", testReceivingCustomPayload),
    ]
}
