import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import NIOCore

public func createClient(apiKey: String, timeout: TimeAmount = .minutes(20)) throws -> Client {

    let serverURL = try Servers.Server1.url()
    let client = Client(
        serverURL: serverURL,
        configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds),
        transport: AsyncHTTPClientTransport(configuration: AsyncHTTPClientTransport.Configuration(timeout: timeout)),
        middlewares: [
            AuthenticationMiddleware(apiKey: apiKey),
            UnescapeGoogUploadHeadersMiddleware(),
        ]
    )

    return client
}
