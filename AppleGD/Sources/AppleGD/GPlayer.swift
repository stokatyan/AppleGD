//
//  GPlayer.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/21/25.
//

import GameKit
import SwiftGodot

@Godot
class GPlayer: RefCounted {
    
    @Export var gamePlayerID: String = ""
    @Export var displayName: String = ""
    @Export var alias: String = ""
    @Export var playerID: String = ""
    @Export var guestIdentifier: String = ""
    
    
    func set(_ player: GKPlayer) {
        gamePlayerID = player.gamePlayerID
        displayName = player.displayName
        alias = player.alias
        playerID = player.playerID
        guestIdentifier = player.guestIdentifier ?? ""
    }
}
