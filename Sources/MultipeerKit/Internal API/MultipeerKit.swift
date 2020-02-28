//
//  File.swift
//  
//
//  Created by Guilherme Rambo on 28/02/20.
//

import Foundation
import os.log

struct MultipeerKit {
    static let subsystemName = "codes.rambo.MultipeerKit"

    static func log(for type: AnyClass) -> OSLog {
        OSLog(subsystem: subsystemName, category: String(describing: type))
    }
}
