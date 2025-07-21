//
//  GKLocalPlayerAuth.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/21/25.
//

import GameKit

class GKLocalPlayerAuth {
        
    init(delegate: GameKitNode) {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                ViewControllerPresenter.present(viewController)
                return
            }
            if let error {
                print("Swift (GKLocalPlayerAuth): \(error)")
                return
            }
            
            print("Swift (GKLocalPlayerAuth): local player authenticated")
            
            // Player is available.
            // Check if there are any player restrictions before starting the game.
                    
            if GKLocalPlayer.local.isUnderage {
                // Hide explicit game content.
            }


            if GKLocalPlayer.local.isMultiplayerGamingRestricted {
                // Disable multiplayer game features.
            }


            if GKLocalPlayer.local.isPersonalizedCommunicationRestricted {
                // Disable in game communication UI.
            }
            
            delegate.refreshFailedLeaderboards()
        }
    }
    
    
}
