import OpenAPIAsyncHTTPClient
import OpenAPIRuntime

public func createClient(apiKey: String) throws -> Client {

    let serverURL = try Servers.Server1.url()
    let client = Client(
        serverURL: serverURL,
        configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds),
        transport: AsyncHTTPClientTransport(),
        middlewares: [
            AuthenticationMiddleware(apiKey: apiKey),
            UnescapeGoogUploadHeadersMiddleware(),
        ]
    )

    return client
}
