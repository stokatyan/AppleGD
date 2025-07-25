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
    
    private var gameCenterDelegate = GameCenterDelegate()
    private var localPlayerAuth: GKLocalPlayerAuth?
    
    private var player: GKLocalPlayer {
        GKLocalPlayer.local
    }
    
    private var failedLeaderboardIds = Set<String>()
    
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
    
    func refreshFailedLeaderboards() {
        refreshLeaderboards(ids: Array(failedLeaderboardIds))
    }
    
    private func setupPlayerAuth() {
        localPlayerAuth = GKLocalPlayerAuth(delegate: self)
    }
    
    /**
     Fetches the leaderboards for the given ids, and then load's the player's entry for each leaderboard.
     The `didLoadPlayerEntry` is emitted for each entry that is loaded for the player.
     */
    @Callable(autoSnakeCase: true)
    func refreshLeaderboards(ids: [String]) {
        let signal = didLoadPlayerEntry
        let player = player
        if !player.isAuthenticated || localPlayerAuth == nil {
            setupPlayerAuth()
        }
        Task {
            do {
                let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: ids)
                            
                for leaderboard in leaderboards {
                    leaderboard.loadEntries(for: [player], timeScope: .allTime) { entry, entries, error in
                        guard let entry, error == nil else {
                            print("Swift (refreshLeaderboards): error refreshing leaderboard \(leaderboard.baseLeaderboardID)")
                            if let entry {
                                print("entry: \(entry)")
                            }
                            if let error {
                                print("error: \(error)")
                            }
                            self.failedLeaderboardIds.insert(leaderboard.baseLeaderboardID)
                            return
                        }

                        self.failedLeaderboardIds.remove(leaderboard.baseLeaderboardID)
                        signal.emit(leaderboard.baseLeaderboardID, entry.score, entry.rank)
                    }
                }
            } catch {
                print("Swift (refreshLeaderboards): Failed to load leaderboards")
                print("     error:\n\(error)")
                for id in ids {
                    failedLeaderboardIds.insert(id)
                }
            }
        }
    }
    
    /**
     - Returns the loaded player as a `Dictionary`.
     */
    @Callable(autoSnakeCase: true)
    func getLoadedPlayer() -> GPlayer {
        var gPlayer = GPlayer()
        gPlayer.set(player)
        return gPlayer
    }

    /**
     Shows the native Game Center leaderboard for the given id.
     */
    @Callable(autoSnakeCase: true)
    func showLeaderboard(leaderboardId: String) {
        #if os(iOS)
        Task { @MainActor in
            let viewController = GKGameCenterViewController(
                leaderboardID: leaderboardId,
                playerScope: .global,
                timeScope: .allTime
            )
            viewController.gameCenterDelegate = gameCenterDelegate
            ViewControllerPresenter.present(viewController)
        }
        #endif
    }
    
    /**
     Submits the current player's score for the leaderboard with the given id.
     */
    @Callable(autoSnakeCase: true)
    func submitScore(score: Int, leaderboardIds: [String]) {
        GKLeaderboard.submitScore(score, context: 0, player: player, leaderboardIDs: leaderboardIds) { error in
            self.didSubmitScore.emit(error == nil)
            print("Swift (submitScore): did submit score")
            guard error == nil else {
                print("Swift (submitScore): \(error)")
                return
            }
            self.refreshLeaderboards(ids: leaderboardIds)
        }
    }
}

extension GameKitNode: @unchecked Sendable { }
