//
//  main.swift
//  NetworkTLSClient
//
//  Created by Ian Campbell on 2019-10-18.
//  Copyright © 2019 Ian Campbell. All rights reserved.
//

import Foundation
import Network
import NetworkExtension
import CryptoKit

extension Data {

    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }

    func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return value
    }
}

// Game State data
var updateUserPrompt: Bool = true
var userName: String? = nil
var userID: UInt8 = 255
var gameData: GameData? = nil

// Receive a message, deliver it to your delegate, and continue receiving more messages.
func receiveNextMessage(connection: NWConnection) {
    connection.receiveMessage { (content, context, isComplete, error) in
        // Extract your message type from the received context.
        if let gameMessage = context?.protocolMetadata(definition: GameProtocol.definition) as? NWProtocolFramer.Message {
            receivedMessage(content: content, message: gameMessage)
        }
        if error == nil {
            // Continue to receive more messages until you receive and error.
            receiveNextMessage(connection: connection)
        }
    }
}

func receivedMessage(content: Data?, message: NWProtocolFramer.Message) {
    guard let content = content else {
        return
    }
    switch message.gameMessageType {
    case .USER_NAME:
        print("Received user name message")
    case .SERVER_WELCOME:
        userID = content[0];
        print("Server Welcome Message: playerID=\(userID)")

    case .ADD_PLAYER:
        /*
         ADD PLAYER Message
         - content[0]: playerID
         - content[1..]: playerName
         */
        let playerID = content[0];
        let playerName = String(decoding: content.subdata(in: 1..<content.count), as: UTF8.self)
        print("Add Player Message: playerID=\(playerID); playerName=\(playerName)")
        
        if let gameData = gameData {
            gameData.addPlayer(playerID: playerID, playerName: playerName)
        }
        
    case .SET_ACTIVE_PLAYER:
        /*
         SET ACTIVE PLAYER Message
         - content[0]: playerID
         */
        let playerID = content[0];
        print("Set Active Player Message: playerID=\(playerID)")
        
        if let gameData = gameData {
            gameData.setActivePlayer(playerID: playerID)
        }

    case .GAME_DATA:
        /*
         GAME DATA Message
         - maxPlayers (uint8)
         - maxMove (uint8)
         - gameBoardSize (uint8)
         */
        let gameDataMaxPlayers = content[0];
        let gameDataMaxMove = content[1];
        let gameDataGameBoardSize = content[2];
        print("Game Data Message: maxPlayers=\(gameDataMaxPlayers); maxMove=\(gameDataMaxMove); gameBoardSize=\(gameDataGameBoardSize)")
        
        gameData = GameData(maxPlayers: gameDataMaxPlayers, maxMove: gameDataMaxMove, gameBoardSize: gameDataGameBoardSize)
    case .MOVE_PLAYER:
        /*
         MOVE PLAYER Message
         - content[0]: playerID
         - content[1]: playerMove
         */
        let playerID = content[0];
        let playerMove = content[1];
        print("Move Player Message: playerID=\(playerID), playerMove=\(playerMove)")
        
        if let gameData = gameData {
            gameData.movePlayer(playerID: playerID, playerMove: playerMove)
        }
    default:
        print("Unknown message type")
    }
    updateUserPrompt = true
    printGamePrompt()
}

// Handle sending a "User Name" message.
func sendUserName(_ userName: String, connection: NWConnection?) {
    guard let connection = connection else {
        return
    }

    // Create a message object to hold the command type.
    let message = NWProtocolFramer.Message(gameMessageType: .USER_NAME)
    let context = NWConnection.ContentContext(identifier: "User Name",
                                              metadata: [message])

    // Send the application content along with the message.
    connection.send(content: userName.data(using: .utf8), contentContext: context, isComplete: true, completion: .idempotent)
}

// Handle sending a "Player Move" message.
func sendPlayerMove(_ playerMove: UInt8, connection: NWConnection?) {
    guard let connection = connection else {
        return
    }

    // Create a message object to hold the command type.
    let message = NWProtocolFramer.Message(gameMessageType: .PLAYER_MOVE)
    let context = NWConnection.ContentContext(identifier: "Player Move",
                                              metadata: [message])
    
    var content = Data()
    content.append(playerMove)

    // Send the application content along with the message.
    connection.send(content: content, contentContext: context, isComplete: true, completion: .idempotent)
}

func printGamePrompt() {
    guard (updateUserPrompt) else {
        return
    }
    for _ in 0..<100 {
        print("")
    }
    
    if let userName = userName {
        print("Player: \(userName)")
        
        if let gameData = gameData {
            print("Active Player: \(gameData.activePlayer)")
            print("Max Move: \(gameData.maxMove)")
            print("Game Board", terminator: ":")
            print(gameData.gameBoard)
            print("Game Total: \(gameData.gameBoard.count)")
            print("Game Players", terminator: ":")
            print(gameData.playerNames)
            print("Board Size: \(gameData.gameBoardSize)")
            
            // Print game status
            if gameData.isGameOver() {
                if gameData.activePlayer == userID {
                    print("Status: Game Over - You have lost...")
                } else {
                    print("Status: Game Over - You have WON!!!")
                }
                print("Play again (yes/no)?", terminator: " > ")
            } else {
                if gameData.activePlayer == userID {
                    print("Enter next move (1,2,3)", terminator: " > ")
                } else {
                    print("Status: Waiting for other player to move")
                    print("", terminator: "> ")
                }
            }
        } else {
            print("Status: Waiting for opponent", terminator: " > ")
        }
    } else {
        print("Please enter user name")
        print("", terminator: "> ")
    }
    updateUserPrompt = false
}

let tcpOptions = NWProtocolTCP.Options()
tcpOptions.enableKeepalive = true
tcpOptions.keepaliveIdle = 2

let tlsOptions = NWProtocolTLS.Options()

sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
sec_protocol_options_set_max_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)

// Create parameters with custom TLS and TCP options.
var tlsParameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)

tlsParameters.includePeerToPeer = true

// Add your custom game protocol to support game messages.
let gameOptions = NWProtocolFramer.Options(definition: GameProtocol.definition)
tlsParameters.defaultProtocolStack.applicationProtocols.insert(gameOptions, at: 0)

let connection = NWConnection(host: "127.0.0.1", port: 9797, using: tlsParameters)

connection.stateUpdateHandler = { newState in
    switch newState {
    case .ready:
        print("\(connection) established")

        // When the connection is ready, start receiving messages.
        receiveNextMessage(connection: connection)

    default:
        break
    }
}

connection.start(queue: DispatchQueue(label: "tls"))

while (true) {
    updateUserPrompt = true
    printGamePrompt()
    let response = readLine()
    if let response = response {
        if userName == nil {
            userName = response
            sendUserName(response, connection: connection)
            updateUserPrompt = true
        } else if let gameData = gameData {
            if gameData.isGameOver() {
                // TODO implement restart game/quit game logic
            } else {
                // Parse player move
                if let playerMove = UInt8(response) {
                    sendPlayerMove(playerMove, connection: connection)
                }
                
            }
        }

    }
    
    /*
    print("\(connection)")
    print("\(connection.state)")
    let metadata = connection.metadata(definition: NWProtocolTLS.definition) as! NWProtocolTLS.Metadata
    let tlsProtocolVersion = sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata.securityProtocolMetadata)
    let tlsServerName = sec_protocol_metadata_get_server_name(metadata.securityProtocolMetadata)
    let tlsCipher = sec_protocol_metadata_get_negotiated_tls_ciphersuite(metadata.securityProtocolMetadata)
    
    print("\(tlsProtocolVersion)")
    print("\(tlsCipher)")
 */
}
