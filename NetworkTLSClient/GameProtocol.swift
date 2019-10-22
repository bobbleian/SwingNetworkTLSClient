/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implement a custom framer protocol to encode game-specific messages over a stream.
*/

import Foundation
import Network

// Define the types of commands your game will use.
enum GameMessageType: UInt8 {
    case USER_NAME = 0
    case GAME_DATA = 4
    case ADD_PLAYER = 5
    case SERVER_WELCOME = 8
    case UNKNOWN = 255
}

// Create a class that implements a framing protocol.
class GameProtocol: NWProtocolFramerImplementation {

    // Create a global definition of your game protocol to add to connections.
    static let definition = NWProtocolFramer.Definition(implementation: GameProtocol.self)

    // Set a name for your protocol for use in debugging.
    static var label: String { return "Ten" }

    // Set the default behavior for most framing protocol functions.
    required init(framer: NWProtocolFramer.Instance) { }
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { return .ready }
    func wakeup(framer: NWProtocolFramer.Instance) { }
    func stop(framer: NWProtocolFramer.Instance) -> Bool { return true }
    func cleanup(framer: NWProtocolFramer.Instance) { }

    // Whenever the application sends a message, add your protocol header and forward the bytes.
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        // Extract the type of message.
        let type = message.gameMessageType

        // Create a header using the type and length.
        let header = GameProtocolHeader(type: type.rawValue, length: UInt8(messageLength))

        // Write the header.
        framer.writeOutput(data: header.encodedData)

        // Ask the connection to insert the content of the application message after your header.
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch let error {
            print("Hit error writing \(error)")
        }
    }

    // Whenever new bytes are available to read, try to parse out your message format.
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            // Try to read out a single header.
            var tempHeader: GameProtocolHeader? = nil
            let headerSize = GameProtocolHeader.encodedSize
            let parsed = framer.parseInput(minimumIncompleteLength: headerSize,
                                           maximumLength: headerSize) { (buffer, isComplete) -> Int in
                guard let buffer = buffer else {
                    return 0
                }
                if buffer.count < headerSize {
                    return 0
                }
                tempHeader = GameProtocolHeader(buffer)
                return headerSize
            }

            // If you can't parse out a complete header, stop parsing and ask for headerSize more bytes.
            guard parsed, let header = tempHeader else {
                return headerSize
            }

            // Create an object to deliver the message.
            var messageType = GameMessageType.UNKNOWN
            if let parsedMessageType = GameMessageType(rawValue: header.type) {
                messageType = parsedMessageType
            }
            let message = NWProtocolFramer.Message(gameMessageType: messageType)

            // Deliver the body of the message, along with the message object.
            if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
                return 0
            }
        }
    }
}

// Extend framer messages to handle storing your command types in the message metadata.
extension NWProtocolFramer.Message {
    convenience init(gameMessageType: GameMessageType) {
        self.init(definition: GameProtocol.definition)
        self.gameMessageType = gameMessageType
    }

    var gameMessageType: GameMessageType {
        get {
            if let type = self["GameMessageType"] as? GameMessageType {
                return type
            } else {
                return .UNKNOWN
            }
        }
        set {
            self["GameMessageType"] = newValue
        }
    }
}

// Define a protocol header struct to help encode and decode bytes.
struct GameProtocolHeader: Codable {
    let type: UInt8
    let length: UInt8

    init(type: UInt8, length: UInt8) {
        self.type = type
        self.length = length
    }

    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempType: UInt8 = 0
        var tempLength: UInt8 = 0
        withUnsafeMutableBytes(of: &tempType) { typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                            count: MemoryLayout<UInt8>.size))
        }
        withUnsafeMutableBytes(of: &tempLength) { lengthPtr in
            lengthPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt8>.size),
                                                              count: MemoryLayout<UInt8>.size))
        }
        type = tempType
        length = tempLength
    }

    var encodedData: Data {
        var tempType = type
        var tempLength = length
        var data = Data(bytes: &tempType, count: MemoryLayout<UInt8>.size)
        data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt8>.size))
        return data
    }

    static var encodedSize: Int {
        return MemoryLayout<UInt8>.size * 2
    }
}
