import UIKit
import SwiftUI
import MultipeerKit
import Security

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private let transceiver = MultipeerTransceiver.example

    private lazy var dataSource = MultipeerDataSource.example

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        activateTransceiver()

        let rootView = RootView()
            .environmentObject(dataSource)

        guard let windowScene = scene as? UIWindowScene else { fatalError() }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: rootView)
        self.window = window
        window.makeKeyAndVisible()
    }

    private func activateTransceiver() {
        transceiver.resume()
    }

    func sceneDidDisconnect(_ scene: UIScene) { }

    func sceneDidBecomeActive(_ scene: UIScene) { }

    func sceneWillResignActive(_ scene: UIScene) { }

    func sceneWillEnterForeground(_ scene: UIScene) { }

    func sceneDidEnterBackground(_ scene: UIScene) { }

}

