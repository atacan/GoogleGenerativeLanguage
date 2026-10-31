import GoogleGenerativeLanguage
import GoogleGenerativeLanguageTypes
import NIOCore
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime

/// Creates an AsyncHTTPClient-backed Gemini client with the provider defaults.
public func createClient(apiKey: String, timeout: TimeAmount = .minutes(20)) throws -> Client {
    Client.asyncHTTPClient(
        serverURL: try Servers.Server1.url(),
        authentication: .apiKey(apiKey),
        transportConfiguration: .init(timeout: timeout)
    )
}
