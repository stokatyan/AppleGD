//
//  ViewControllerPresenter.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/18/25.
//

import UIKit

public class ViewControllerPresenter {
    
    public static func present(_ viewController: UIViewController, animated: Bool = true) {
        Task { @MainActor in
            guard let topVC = topViewController() else {
                print("No view controller to present from")
                return
            }
            topVC.present(viewController, animated: animated, completion: nil)
        }
    }

    @MainActor
    private static func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {

        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }

        if let tab = base as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }

        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }

        return base
    }
}
