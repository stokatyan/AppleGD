//
//  GameCenter.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/18/25.
//

import SwiftGodot
import GameKit

@Godot
class GameKitNode: Node {
    
    private var player: GKPlayer?
    private var leaderboardMap = [String: GKLeaderboard]()
    
    @Signal var didLoadLeaderboards: SignalWithArguments<[String]>
    
    @Callable(autoSnakeCase: true)
    func getLeaderboards(ids: [String]) {
        Task {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: ids)
        }
    }
    
    @Callable(autoSnakeCase: true)
    func getLoadedPlayer() -> [String: String] {
        var result = [String: String]()
        
        guard let player else {
            return result
        }
        
        result["gamePlayerID"] = player.gamePlayerID
        result["displayName"] = player.displayName
        result["alias"] = player.alias
        result["playerID"] = player.playerID
        result["guestIdentifier"] = player.guestIdentifier
        
        return result
    }

    @Callable(autoSnakeCase: true)
    func showLeaderboard(leaderboardId: String) {
        Task { @MainActor in
            let viewController = GKGameCenterViewController(
                leaderboardID: leaderboardId,
                playerScope: .global,
                timeScope: .allTime
            )
            ViewControllerPresenter.present(viewController)
        }
    }
    
    @Callable(autoSnakeCase: true)
    func submitScore(score: Int, context: Int, leaderboardIds: [String]) {
        guard let player else {
            return
        }

        GKLeaderboard.submitScore(score, context: context, player: player, leaderboardIDs: leaderboardIds) { error in
            return
        }
    }
}
