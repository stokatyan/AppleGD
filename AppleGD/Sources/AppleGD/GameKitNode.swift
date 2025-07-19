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
    
    /**
     Signal that emits the player's entries for a leaderboard.
     
     - parameters:
        - leaderboardId: String
        - score: Int
        - rank: Int
     */
    @Signal var didLoadPlayerEntry: SignalWithArguments<String, Int, Int>
    
    /**
     Signal that emits when a score completed being submitted.
     - parameters:
        - didSucceed: Bool
     */
    @Signal var didSubmitScore: SignalWithArguments<Bool>
    
    /**
     Fetches the leaderboards for the given ids, and then load's the player's entry for each leaderboard.
     The `didLoadPlayerEntry` is emitted for each entry that is loaded for the player.
     */
    @Callable(autoSnakeCase: true)
    func refreshLeaderboards(ids: [String]) {
        let signal = didLoadPlayerEntry
        Task {
            guard let leaderboards = try? await GKLeaderboard.loadLeaderboards(IDs: ids) else {
                return
            }
            
            var ids = [String]()
            for leaderboard in leaderboards {
                ids.append(leaderboard.baseLeaderboardID)
            }
                        
            for leaderboard in leaderboards {
                leaderboard.loadEntries(for: [player], timeScope: .allTime) { entry, entries, error in
                    guard let entry, error == nil else { return }
                    signal.emit(leaderboard.baseLeaderboardID, entry.score, entry.score)
                }
            }
        }
    }
    
    /**
     - Returns the loaded player as a `Dictionary`.
     */
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

    /**
     Shows the native Game Center leaderboard for the given id.
     */
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
    
    /**
     Submits the current player's score for the leaderboard with the given id.
     */
    @Callable(autoSnakeCase: true)
    func submitScore(score: Int, leaderboardIds: [String]) {
        let signal = didSubmitScore
        GKLeaderboard.submitScore(score, context: 0, player: player, leaderboardIDs: leaderboardIds) { error in
            self.didSubmitScore.emit(error == nil)
            guard error == nil else { return }
            self.refreshLeaderboards(ids: leaderboardIds)
        }
    }
}

extension GameKitNode: @unchecked Sendable { }
