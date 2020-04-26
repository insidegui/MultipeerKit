# MultipeerConfiguration.Invitation

Defines how the multipeer connection handles newly discovered peers.
New peers can be invited automatically, invited with a custom context and timeout,
or not invited at all, in which case you must invite them manually.

``` swift
public enum Invitation
```

## Enumeration Cases

### `automatic`

When `.automatic` is used, all found peers will be immediately invited to join the session.

``` swift
case automatic
```

### `custom`

Use `.custom` when you want to control the invitation of new peers to your session,
but still invite them at the time of discovery.

``` swift
case custom(: (Peer) throws -> (context: Data, timeout: TimeInterval)?)
```

### `none`

Use `.none` when you want to manually invite peers by calling `invite` in `MultipeerTransceiver`.

``` swift
case none
```
