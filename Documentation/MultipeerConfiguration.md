# MultipeerConfiguration

Configures several aspects of the multipeer communication.

``` swift
public struct MultipeerConfiguration
```

## Initializers

### `init(serviceType:peerName:defaults:security:invitation:)`

Creates a new configuration.

``` swift
public init(serviceType: String, peerName: String, defaults: UserDefaults, security: Security, invitation: Invitation)
```

#### Parameters

  - serviceType: This must be the same accross your app running on multiple devices, it must be a short string. Check Apple's docs on `MCNearbyServiceAdvertiser` for more info on the limitations for this field.
  - peerName: A display name for this peer that will be shown to nearby peers.
  - defaults: An instance of `UserDefaults` that's used to store this peer's identity so that it remains stable between different sessions. If you use MultipeerKit in app extension make sure to use a shared app group if you wish to maintain a stable identity.
  - security: The security configuration.
  - invitation: Defines how the multipeer connection handles newly discovered peers. New peers can be invited automatically, invited with a custom context or not invited at all, in which case you must invite them manually.

## Properties

### `serviceType`

This must be the same accross your app running on multiple devices,
it must be a short string.

``` swift
var serviceType: String
```

Check Apple's docs on `MCNearbyServiceAdvertiser` for more info on the limitations for this field.

### `peerName`

A display name for this peer that will be shown to nearby peers.

``` swift
var peerName: String
```

### `defaults`

An instance of `UserDefaults` that's used to store this peer's identity so that it
remains stable between different sessions. If you use MultipeerKit in app extensions,
make sure to use a shared app group if you wish to maintain a stable identity.

``` swift
var defaults: UserDefaults
```

### `security`

The security configuration.

``` swift
var security: Security
```

### `invitation`

Defines how the multipeer connection handles newly discovered peers.

``` swift
var invitation: Invitation
```

### `` `default` ``

The default configuration, uses the service type `MKSVC`, the name of the device/computer as the
display name, `UserDefaults.standard`, the default security configuration and automatic invitation.

``` swift
let `default`
```
