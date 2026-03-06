import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2TransportServices
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
        try await withConnectedClient(host: host, port: port) { client in
            let message = try await client.unary(
                request: ClientRequest(message: Greeting_V1_ListLanguagesRequest()),
                descriptor: MethodDescriptor(
                    fullyQualifiedService: "greeting.v1.GreetingService",
                    method: "ListLanguages"
                ),
                serializer: ProtobufSerializer<Greeting_V1_ListLanguagesRequest>(),
                deserializer: ProtobufDeserializer<Greeting_V1_ListLanguagesResponse>(),
                options: .defaults,
                onResponse: { response in
                try response.message
                }
            )
            return message.languages.map { lang in
                Language(code: lang.code, name: lang.name, native: lang.native_p)
            }
        }
    }

    func sayHello(name: String, langCode: String) async throws -> String {
        try await withConnectedClient(host: host, port: port) { client in
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
                deserializer: ProtobufDeserializer<Greeting_V1_SayHelloResponse>(),
                options: .defaults,
                onResponse: { response in
                try response.message
                }
            )
            return response.greeting
        }
    }

    private func withConnectedClient<T: Sendable>(
        host: String,
        port: Int,
        _ body: @Sendable (GRPCClient<HTTP2ClientTransport.TransportServices>) async throws -> T
    ) async throws -> T {
        let transport = try HTTP2ClientTransport.TransportServices(
            target: .ipv4(host: host, port: port),
            transportSecurity: .plaintext
        )
        return try await withGRPCClient(transport: transport) { client in
            try await body(client)
        }
    }
}
