import Foundation
import GRPC
import NIOCore
import NIOPosix
import SwiftProtobuf

/// gRPC client for the GreetingService running on the Go daemon.
final class GreetingClient: GRPCClient, @unchecked Sendable {
    let channel: GRPCChannel
    var defaultCallOptions = CallOptions(timeLimit: .timeout(.seconds(2)))
    private let closeAction: () throws -> Void

    init(channel: GRPCChannel, closeAction: @escaping () throws -> Void) {
        self.channel = channel
        self.closeAction = closeAction
    }

    static func direct(host: String, port: Int) throws -> GreetingClient {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let channel = ClientConnection.insecure(group: group).connect(host: host, port: port)
        return GreetingClient(channel: channel) {
            try channel.close().wait()
            try group.syncShutdownGracefully()
        }
    }

    func listLanguages() async throws -> [Language] {
        let response: ProtobufPayload<Greeting_V1_ListLanguagesResponse> = try await performAsyncUnaryCall(
            path: "/greeting.v1.GreetingService/ListLanguages",
            request: ProtobufPayload(message: Greeting_V1_ListLanguagesRequest()),
            responseType: ProtobufPayload<Greeting_V1_ListLanguagesResponse>.self
        )
        return response.message.languages.map { lang in
            Language(code: lang.code, name: lang.name, native: lang.native_p)
        }
    }

    func sayHello(name: String, langCode: String) async throws -> String {
        var request = Greeting_V1_SayHelloRequest()
        request.name = name
        request.langCode = langCode

        let response: ProtobufPayload<Greeting_V1_SayHelloResponse> = try await performAsyncUnaryCall(
            path: "/greeting.v1.GreetingService/SayHello",
            request: ProtobufPayload(message: request),
            responseType: ProtobufPayload<Greeting_V1_SayHelloResponse>.self
        )
        return response.message.greeting
    }

    func close() throws {
        try closeAction()
    }
}

private struct ProtobufPayload<MessageType: SwiftProtobuf.Message & Sendable>: GRPCPayload, Sendable {
    let message: MessageType

    init(message: MessageType) {
        self.message = message
    }

    init(serializedByteBuffer: inout ByteBuffer) throws {
        let data = serializedByteBuffer.readData(length: serializedByteBuffer.readableBytes) ?? Data()
        self.message = try MessageType(serializedBytes: data)
    }

    func serialize(into buffer: inout ByteBuffer) throws {
        let bytes: [UInt8] = try message.serializedBytes()
        buffer.writeBytes(bytes)
    }
}
