# MultipeerKit

A high-level abstraction built on top of Apple's Network framework, which allows iOS, macOS, tvOS and visionOS devices to discover each other over Bonjour and exchange `Codable` payloads over peer-to-peer TCP connections.

> MultipeerKit was originally built on top of MultipeerConnectivity, which Apple has deprecated. The public API is largely the same; see "Migration notes" below for the small differences.

## Sample app

Check the example folder for a sample implementation.

![Sample](../assets/demo.gif?raw=true)

## Info.plist configuration

MultipeerKit uses the local network to discover and connect to peers, so your app must include the following keys in its `Info.plist`:

- `Privacy - Local Network Usage Description` (`NSLocalNetworkUsageDescription`)
- `Bonjour services` (`NSBonjourServices`)

For the privacy key, include a human-readable description of what benefit the user gets by allowing your app to access devices on the local network.

The Bonjour services key is an array of service types your app will browse for. For MultipeerKit, the entry should be in the format `_servicename._tcp`, where `servicename` is the `serviceType` you've set in your `MultipeerConfiguration`. If you're using the default configuration, the value of this key should be `_MKSVC._tcp`.

**If you do not configure the above keys properly, then MultipeerKit won't work.**

## Encryption

When `encryptionPreference` is `.required` (or the deprecated `.optional`):

- If you supply a `SecIdentity` via `MultipeerConfiguration.Security.identity`, MultipeerKit configures TLS at the transport layer using that identity, just like the MultipeerConnectivity-based version did.
- If you do **not** supply an identity, MultipeerKit performs its own ephemeral key exchange during the connection handshake: each side generates an X25519 key pair, the public keys are exchanged inside the HELLO/ACCEPT frames, both sides HKDF-derive a session key, and every subsequent application payload is sealed with ChaCha20-Poly1305. Each session uses a fresh key pair, so the channel has forward secrecy with no certificate management on your side.

The application-layer mode encrypts message contents but does not authenticate the remote peer — anyone running the app with the same `serviceType` can connect and complete the key exchange. If you need per-peer authentication, supply a `SecIdentity` and MultipeerKit will use TLS instead.

## Migration notes

If you're upgrading from the MultipeerConnectivity-based version:

- `Peer.underlyingPeer` (an `MCPeerID`) is gone. Use `Peer.id` (a stable UUID) for identifying peers.
- `MultipeerConfiguration.Security.encryptionPreference` now uses `MultipeerConfiguration.Security.EncryptionPreference` (`.none`, `.optional`, `.required`) instead of `MCEncryptionPreference`. `.optional` is deprecated because the Network framework cannot honour it distinctly.
- `MultipeerConfiguration.Security.identity` is now `SecIdentity?` (was `[Any]?`). Intermediate certificates from the old API are not used.
- Minimum platforms are now iOS 16, macOS 13, tvOS 16, and visionOS 1.

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
        .package(url: "https://github.com/insidegui/MultipeerKit.git", from: "0.4.0")
    ],
    ...
)
```
