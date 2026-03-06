import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf

/// gRPC client for the GreetingService running on the Go daemon.
final class GreetingClient: Sendable {
    private let host: String
    private let port: Int

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    func listLanguages() async throws -> [Language] {
        try await withGRPCClient(host: host, port: port) { client in
            let response = try await client.unary(
                request: ClientRequest(message: Google_Protobuf_Empty()),
                descriptor: MethodDescriptor(
                    fullyQualifiedService: "greeting.v1.GreetingService",
                    method: "ListLanguages"
                ),
                serializer: ProtobufSerializer<Google_Protobuf_Empty>(),
                deserializer: ProtobufDeserializer<Greeting_V1_ListLanguagesResponse>()
            )
            let message = try response.message
            return message.languages.map { lang in
                Language(code: lang.code, name: lang.name, native: lang.native_p)
            }
        }
    }

    func sayHello(name: String, langCode: String) async throws -> String {
        try await withGRPCClient(host: host, port: port) { client in
            var request = Greeting_V1_SayHelloRequest()
            request.name = name
            request.langCode = langCode

            let response = try await client.unary(
                request: ClientRequest(message: request),
                descriptor: MethodDescriptor(
                    fullyQualifiedService: "greeting.v1.GreetingService",
                    method: "SayHello"
                ),
                serializer: ProtobufSerializer<Greeting_V1_SayHelloRequest>(),
                deserializer: ProtobufDeserializer<Greeting_V1_SayHelloResponse>()
            )
            return try response.message.greeting
        }
    }

    private func withGRPCClient<T>(
        host: String,
        port: Int,
        _ body: @Sendable (GRPCClient) async throws -> T
    ) async throws -> T {
        let transport = try HTTP2ClientTransport.Posix(
            target: .ipv4(host: host, port: port)
        )
        let client = GRPCClient(transport: transport)

        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await client.run() }
            let result = try await body(client)
            client.beginGracefulShutdown()
            return result
        }
    }
}
