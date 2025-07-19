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
    
    private var player: GKPlayer {
        GKLocalPlayer.local
    }
    
    @Signal var didLoadLeaderboards: SignalWithArguments<[String]>
    @Signal var didLoadPlayerEntry: SignalWithArguments<String, Int, Int>
    
    @Callable(autoSnakeCase: true)
    func getLeaderboards(ids: [String]) {
        let signal = didLoadLeaderboards
        Task {
            guard let leaderboards = try? await GKLeaderboard.loadLeaderboards(IDs: ids) else {
                return
            }
            
            var ids = [String]()
            for leaderboard in leaderboards {
                ids.append(leaderboard.baseLeaderboardID)
            }
            
            signal.emit(ids)
            
            for leaderboard in leaderbords {
                leaderboard.loadEntries(for: [player], timeScope: .allTime) { entry, entries, error in
                    didLoadPlayerEntry.emit(leaderboard.baseLeaderboardID, entry.score, entry.score)
                }
            }
        }
    }
    
    @Callable(autoSnakeCase: true)
    func getLoadedPlayer() -> [String: String] {
        var result = [String: String]()
        
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
        GKLeaderboard.submitScore(score, context: context, player: player, leaderboardIDs: leaderboardIds) { error in
            return
        }
    }
}
