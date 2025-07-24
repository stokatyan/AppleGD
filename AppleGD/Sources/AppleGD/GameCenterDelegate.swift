//
//  GameCenterDelegate.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/20/25.
//

import GameKit

class GameCenterDelegate: NSObject, GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            #if os(iOS)
            gameCenterViewController.dismiss(animated: true)
            #endif
        }
    }
}
