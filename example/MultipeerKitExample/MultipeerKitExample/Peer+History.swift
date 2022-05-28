//
//  Peer+History.swift
//  MultipeerKitExample
//
//  Created by Oliver Michalak on 28.05.22.
//  Copyright © 2022 Guilherme Rambo. All rights reserved.
//

import Foundation
import MultipeerKit


extension Peer {
	
	var history: [String] {
		get {
			userInfo["history"] as? [String] ?? []
		}
		set {
			userInfo["history"] = newValue
		}
	}

}
