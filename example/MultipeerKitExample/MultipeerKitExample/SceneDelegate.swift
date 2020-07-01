//
//  SceneDelegate.swift
//  MultipeerKitExample
//
//  Created by Guilherme Rambo on 29/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import UIKit
import SwiftUI
import MultipeerKit
import UserNotifications
import Security

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private lazy var transceiver: MultipeerTransceiver = {
        var config = MultipeerConfiguration.default
        config.serviceType = "MPKitDemo"

        config.security.encryptionPreference = .required

        let t = MultipeerTransceiver(configuration: config)

        t.receive(ExamplePayload.self) { [weak self] payload, peer in
            print("Got payload: \(payload)")

            self?.notify(with: payload, peer: peer)
        }

        return t
    }()

    private lazy var dataSource: MultipeerDataSource = {
        MultipeerDataSource(transceiver: transceiver)
    }()

    private func notify(with payload: ExamplePayload, peer: Peer) {
        let content = UNMutableNotificationContent()
        content.body = "\"\(payload.message)\" from \(peer.name)"
        let request = UNNotificationRequest(identifier: payload.message, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in

        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        transceiver.resume()

        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView().environmentObject(dataSource)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in

        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

