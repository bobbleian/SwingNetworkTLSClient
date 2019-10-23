//
//  GameData.swift
//  NetworkTLSClient
//
//  Created by Ian Campbell on 2019-10-23.
//  Copyright © 2019 Ian Campbell. All rights reserved.
//

import Foundation

class GameData {
    var playerNames = [String]()
    var playerIDs = [UInt8]()
    var restartIDs = Set<UInt8>()
    var gameBoard = [UInt8]()
    
    var activePlayer: UInt8
    var maxPlayers: UInt8
    var maxMove: UInt8
    var gameBoardSize: UInt8
    
    var gameState: GameState
    
    init(maxPlayers: UInt8, maxMove: UInt8, gameBoardSize: UInt8) {
        self.maxPlayers = maxPlayers
        self.maxMove = maxMove
        self.gameBoardSize = gameBoardSize
        
        // Randomly set active player
        self.activePlayer = 0
        
        // Set initial GameState
        gameState = WaitingForPlayers()
        
    }
    
    // Delegate to state object
    func addPlayer (playerID: UInt8, playerName: String) {
        gameState = gameState.addPlayer(gameData: self, playerID: playerID, playerName: playerName)
    }
    
    // Delegate to state object
    func setActivePlayer (playerID: UInt8) {
        gameState = gameState.setActivePlayer(gameData: self, playerID: playerID)
    }
    
    // Delegate to state object
    func movePlayer (playerID: UInt8, playerMove: UInt8) {
        gameState = gameState.movePlayer(gameData: self, playerID: playerID, playerMove: playerMove)
    }
    
    // Delegate to state object
    func isGameOver () -> Bool {
        return gameState.isGameOver()
    }
}

protocol GameState {
    func addPlayer (gameData: GameData, playerID: UInt8, playerName: String) -> GameState;
    func movePlayer (gameData: GameData, playerID: UInt8, playerMove: UInt8) -> GameState;
    func setActivePlayer (gameData: GameData, playerID: UInt8) -> GameState;
    func isGameOver () -> Bool;
}

class WaitingForPlayers : GameState {
    func addPlayer(gameData: GameData, playerID: UInt8, playerName: String) -> GameState {
        
        // This should never happen
        guard gameData.playerNames.count < gameData.maxPlayers else {
            return WaitingForMove()
        }
        
        // Add the player and check for max players
        gameData.playerIDs.append(playerID)
        gameData.playerNames.append(playerName)
        
        // Update the game state if necessary
        if gameData.playerNames.count >= gameData.maxPlayers {
            return WaitingForMove()
        }
        
        // Still waiting for more players
        return self
    }
    
    func movePlayer(gameData: GameData, playerID: UInt8, playerMove: UInt8) -> GameState {
        return self
    }
    
    func setActivePlayer(gameData: GameData, playerID: UInt8) -> GameState {
        // Ensure this is a valid playerID
        if gameData.playerIDs.contains(playerID) {
            gameData.activePlayer = playerID
        }
        gameData.activePlayer = playerID
        return self
    }
    
    func isGameOver() -> Bool {
        return false
    }
    
}

class WaitingForMove : GameState {
    func addPlayer(gameData: GameData, playerID: UInt8, playerName: String) -> GameState {
        return self
    }
    
    func movePlayer(gameData: GameData, playerID: UInt8, playerMove: UInt8) -> GameState {
        // Check the active player is making the move
        guard playerID == gameData.activePlayer else {
            return self
        }
        
        // Check for valid move
        guard playerMove > 0 && playerMove <= gameData.maxMove else {
            return self
        }
        
        // Execute move
        for _ in 0..<playerMove {
            gameData.gameBoard.append(playerID)
        }
        
        // Check for loser
        if gameData.gameBoard.count >= gameData.gameBoardSize {
            // Game is Over!
            return GameOver()
        }
        
        // Game continues...advance active player
        let activeIndex = gameData.playerIDs.firstIndex(of: playerID)
        if let activeIndex = activeIndex {
            let nextIndex = (activeIndex + 1) % gameData.playerIDs.count
            gameData.activePlayer = gameData.playerIDs[nextIndex]
        }
        return self
    }
    
    func setActivePlayer(gameData: GameData, playerID: UInt8) -> GameState {
        return self
    }
    
    func isGameOver() -> Bool {
        return false
    }
    
    
}


class GameOver : GameState {
    func addPlayer(gameData: GameData, playerID: UInt8, playerName: String) -> GameState {
        // TODO: Restart implementation
        return self
    }
    
    func movePlayer(gameData: GameData, playerID: UInt8, playerMove: UInt8) -> GameState {
        return self
    }
    
    func setActivePlayer(gameData: GameData, playerID: UInt8) -> GameState {
        return self
    }
    
    func isGameOver() -> Bool {
        // Game IS over!
        return true
    }
    
    
}
