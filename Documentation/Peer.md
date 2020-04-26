# Peer

Represents a remote peer.

``` swift
public struct Peer: Hashable, Identifiable
```

## Inheritance

`Hashable`, `Identifiable`

## Properties

### `id`

The unique identifier for the peer.

``` swift
let id: String
```

### `name`

The peer's display name.

``` swift
let name: String
```

### `discoveryInfo`

Discovery info provided by the peer.

``` swift
let discoveryInfo: [String: String]?
```

### `isConnected`

`true` if we are currently connected to this peer.

``` swift
var isConnected: Bool
```
