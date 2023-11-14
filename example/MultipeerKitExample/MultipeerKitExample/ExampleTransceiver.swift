import SwiftUI
import MultipeerKit

extension MultipeerTransceiver {
    static let example: MultipeerTransceiver = {
        var config = MultipeerConfiguration.default
        config.serviceType = "MPKitDemo"

        config.security.encryptionPreference = .optional

        let t = MultipeerTransceiver(configuration: config)

        return t
    }()
}

extension MultipeerDataSource {
    static let example: MultipeerDataSource = {
        MultipeerDataSource(transceiver: .example)
    }()
}
