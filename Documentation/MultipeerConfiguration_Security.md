# MultipeerConfiguration.Security

Configures security-related aspects of the multipeer connection.

``` swift
public struct Security
```

## Nested Type Aliases

### `InvitationHandler`

``` swift
public typealias InvitationHandler = (Peer, Data?, @escaping (Bool) -> Void) -> Void
```

## Initializers

### `init(identity:encryptionPreference:invitationHandler:)`

``` swift
public init(identity: [Any]?, encryptionPreference: MCEncryptionPreference, invitationHandler: @escaping InvitationHandler)
```

## Properties

### `identity`

An array of information that can be used to identify the peer to other nearby peers.

``` swift
var identity: [Any]?
```

The first object in this array should be a `SecIdentity` object that provides the local peer’s identity.

The remainder of the array should contain zero or more additional SecCertificate objects that provide any
intermediate certificates that nearby peers might require when verifying the local peer’s identity.
These certificates should be sent in certificate chain order.

Check Apple's `MCSession` docs for more information.

### `encryptionPreference`

Configure the level of encryption to be used for communications.

``` swift
var encryptionPreference: MCEncryptionPreference
```

### `invitationHandler`

A custom closure to be used when handling invitations received by remote peers.

``` swift
var invitationHandler: InvitationHandler
```

It receives the `Peer` that sent the invitation, a custom `Data` value
that's a context that can be used to customize the invitation,
and a closure to be called with `true` to accept the invitation or `false` to reject it.

The default implementation accepts all invitations.

### `` `default` ``

The default security configuration, which has no identity, uses no encryption and accepts all invitations.

``` swift
let `default`
```
