import Foundation
import LinkCompassCore

private extension JSONEncoder {
    static var nativeHost: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

struct NativeMessagingIO {
    let input: FileHandle
    let output: FileHandle

    func readMessage() throws -> Data? {
        guard let lengthData = readExactByteCount(4) else { return nil }
        guard lengthData.count == 4 else { throw NativeMessagingError.invalidLengthHeader }
        let length = lengthData.withUnsafeBytes { pointer in
            pointer.load(as: UInt32.self).littleEndian
        }
        guard length <= 1024 * 1024 else { throw NativeMessagingError.messageTooLarge }
        guard let messageData = readExactByteCount(Int(length)), messageData.count == Int(length) else {
            throw NativeMessagingError.incompleteMessage
        }
        return messageData
    }

    private func readExactByteCount(_ byteCount: Int) -> Data? {
        var data = Data()
        while data.count < byteCount {
            let chunk = input.readData(ofLength: byteCount - data.count)
            if chunk.isEmpty {
                return data.isEmpty ? nil : data
            }
            data.append(chunk)
        }
        return data
    }

    func writeMessage(_ data: Data) throws {
        var length = UInt32(data.count).littleEndian
        let lengthData = Data(bytes: &length, count: 4)
        output.write(lengthData)
        output.write(data)
    }
}

enum NativeMessagingError: LocalizedError {
    case invalidLengthHeader
    case messageTooLarge
    case incompleteMessage

    var errorDescription: String? {
        switch self {
        case .invalidLengthHeader:
            return "Invalid native messaging length header"
        case .messageTooLarge:
            return "Native message exceeds 1 MiB limit"
        case .incompleteMessage:
            return "Native message ended before declared length"
        }
    }
}

struct LinkCompassNativeHost {
    let io: NativeMessagingIO
    let handler: NativeHostMessageHandler

    func run() throws {
        while let message = try io.readMessage() {
            let response = handler.handle(message)
            let responseData = try JSONEncoder.nativeHost.encode(response)
            try io.writeMessage(responseData)
        }
    }
}

do {
    let handler = NativeHostMessageHandler(
        routeStore: PendingRouteStore(persistence: try JSONPendingRoutePersistence()),
        ruleStore: RuleStore(persistence: try JSONPreferencesStore())
    )
    try LinkCompassNativeHost(
        io: NativeMessagingIO(input: .standardInput, output: .standardOutput),
        handler: handler
    ).run()
} catch {
    let response = NativeHostResponse.failure(error.localizedDescription)
    if let data = try? JSONEncoder.nativeHost.encode(response) {
        try? NativeMessagingIO(input: .standardInput, output: .standardOutput).writeMessage(data)
    }
    exit(1)
}
