# MultipeerTransceiver

Handles all aspects related to the multipeer communication.

``` swift
public final class MultipeerTransceiver
```

## Initializers

### `init(configuration:)`

Initializes a new transceiver.

``` swift
public init(configuration: MultipeerConfiguration = .default)
```

#### Parameters

  - configuration: The configuration, uses the default configuration if none specified.

## Properties

### `availablePeersDidChange`

Called on the main queue when available peers have changed (new peers discovered or peers removed).

``` swift
var availablePeersDidChange: ([Peer]) -> Void
```

### `peerAdded`

Called on the main queue when a new peer discovered.

``` swift
var peerAdded: (Peer) -> Void
```

### `peerRemoved`

Called on the main queue when a peer removed.

``` swift
var peerRemoved: (Peer) -> Void
```

### `availablePeers`

All peers currently available for invitation, connection and data transmission.

``` swift
var availablePeers: [Peer]
```

## Methods

### `receive(_:using:)`

Configures a new handler for a specific `Codable` type.

``` swift
public func receive<T: Codable>(_ type: T.Type, using closure: @escaping (_ payload: T) -> Void)
```

MultipeerKit communicates data between peers as JSON-encoded payloads which originate with
`Codable` entities. You register a closure to handle each specific type of entity,
and this closure is automatically called by the framework when a remote peer sends
a message containing an entity that decodes to the specified type.

#### Parameters

  - type: The `Codable` type to receive.
  - closure: The closure that will be called whenever a payload of the specified type is received.
  - payload: The payload decoded from the remote message.

### `resume()`

Resumes the transceiver, allowing this peer to be discovered and to discover remote peers.

``` swift
public func resume()
```

### `stop()`

Stops the transceiver, preventing this peer from discovering and being discovered.

``` swift
public func stop()
```

### `broadcast(_:)`

Sends a message to all connected peers.

``` swift
public func broadcast<T: Encodable>(_ payload: T)
```

#### Parameters

  - payload: The payload to be sent.

### `send(_:to:)`

Sends a message to a specific peer.

``` swift
public func send<T: Encodable>(_ payload: T, to peers: [Peer])
```

#### Parameters

  - payload: The payload to be sent.
  - peers: An array of peers to send the message to.

### `invite(_:with:timeout:completion:)`

Manually invite a peer for communicating.

``` swift
public func invite(_ peer: Peer, with context: Data?, timeout: TimeInterval, completion: InvitationCompletionHandler?)
```

You can call this method to manually invite a peer for communicating if you set the
`invitation` parameter to `.none` in the transceiver's `configuration`.

> Warning: If the invitation parameter is not set to `.none`, you shouldn't call this method, since the transceiver does the inviting automatically.

#### Parameters

  - peer: The peer to be invited.
  - context: Custom data to be sent alongside the invitation.
  - timeout: How long to wait for the remote peer to accept the invitation.
  - completion: Called when the invitation succeeds or fails.
