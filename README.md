# MultipeerKit

A high-level abstraction built on top of the MultipeerConnectivity framework, which allows iOS, macOS and tvOS devices to exchange data between them over Wi-Fi networks, peer-to-peer Wi-Fi, and Bluetooth.

## Sample app

Check the example folder for a sample implementation.

![Sample](../assets/demo.gif?raw=true)

## Usage

The main class in this library is `MultipeerTransceiver`, which does both the sending and receiving aspects of the multipeer communication.

MultipeerKit can transmit and receive anything that conforms to the `Codable` protocol, which makes it easy for you to define your own message types.

```swift
// Create a transceiver (make sure you store it somewhere, like a property)
let transceiver = MultipeerTransceiver()

// Start it up!
transceiver.resume()

// Configure message receivers
transceiver.receive(SomeCodableThing.self) { payload, sender in
print("Got my thing from \(sender.name)! \(payload)")
}

// Broadcast message to peers
let payload = SomeEncodableThing()
transceiver.broadcast(payload)
```

For more information on how to use MultipeerKit, check out the [documentation](https://multipeerkit.rambo.codes).

## Integrating

MultipeerKit is a Swift package, to use it in your project, add this to your `Package.swift` file:

```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/insidegui/MultipeerKit.git", from: "0.2.0")
    ],
    ...
)
```
