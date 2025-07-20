//
//  ViewControllerPresenter.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/18/25.
//

#if os(iOS)
import UIKit


public class ViewControllerPresenter {
    
    public static func present(_ viewController: UIViewController, animated: Bool = true) {
        Task { @MainActor in
            guard let topVC = getGodotRootViewController() else {
                print("No view controller to present from")
                return
            }
            topVC.present(viewController, animated: animated, completion: nil)
        }
    }
    
    /// Get the active `UIWindowScene`
    @MainActor
    public static var activeWindowScene: UIWindowScene? {
        // Try the standard method first
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            return scene
        }

        // Fallback: Find any key window and return its scene
        return UIApplication.shared.windows
            .first(where: { $0.isKeyWindow })?
            .windowScene
    }
    
    @MainActor
    private static func getGodotRootViewController() -> UIViewController? {
        // Look for the window with the Godot view
        for window in UIApplication.shared.windows {
            if let root = window.rootViewController, window.isKeyWindow {
                return root
            }
        }
        return nil
    }
}

#endif
