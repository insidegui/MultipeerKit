# MultipeerKit

A high-level abstraction built on top of the MultipeerConnectivity framework, which allows iOS, macOS and tvOS devices to exchange data between them over Wi-Fi networks, peer-to-peer Wi-Fi, and Bluetooth.

## Usage

The main class in this library is `MultipeerTransceiver`, which does both the sending and receiving aspects of the multipeer communication.

MultipeerKit can transmit and receive anything that conforms to the `Codable` protocol, which makes it easy for you to define your own message types.

```swift
// Create a transceiver (make sure you store it somewhere, like a property)
let transceiver = MultipeerTransceiver()

// Start it up!
transceiver.resume()

// Configure message receivers
transceiver.receive(SomeCodableThing.self) { payload in
	print("Got my thing! \(payload)")
}

// Broadcast message to peers
let payload = SomeEncodableThing()
transceiver.broadcast(payload)
```