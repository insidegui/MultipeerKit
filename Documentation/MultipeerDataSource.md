# MultipeerDataSource

``` swift
@available(tvOS 13.0, *) @available(OSX 10.15, *) @available(iOS 13.0, *) public final class MultipeerDataSource: ObservableObject
```

## Inheritance

`ObservableObject`

## Initializers

### `init(transceiver:)`

Initializes a new data source.

``` swift
public init(transceiver: MultipeerTransceiver)
```

#### Parameters

  - transceiver: The transceiver to be used by this data source. Note that the data source will set `availablePeersDidChange` on the transceiver, so if you wish to use that closure yourself, you won't be able to use the data source.

## Properties

### `transceiver`

``` swift
let transceiver: MultipeerTransceiver
```

### `availablePeers`

Peers currently available for invitation, connection and data transmission.

``` swift
var availablePeers: [Peer]
```
