import Foundation
import GoogleGenerativeLanguage
import GoogleGenerativeLanguageAsyncHTTPClient
import GoogleGenerativeLanguageTypes
import GoogleGenerativeLanguageURLSession
import HTTPTypes
import OpenAPIRuntime
import Testing

private struct StubTransport: ClientTransport {
    let check: @Sendable (HTTPRequest, HTTPBody?, String) async throws -> Void
    let json: String
    var contentType: String = "application/json"

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        try await check(request, body, operationID)
        return (HTTPResponse(status: .ok, headerFields: [.contentType: contentType]), HTTPBody(json))
    }
}

private struct StubResponse: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        (
            HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]),
            HTTPBody(#"{"name":"files/example","createTime":"2026-10-31T10:20:30.123Z"}"#)
        )
    }
}

struct GenerationRegressionTests {
    private let serverURL = URL(string: "https://generativelanguage.googleapis.com")!

    @Test func partPreservesMetadataAndNewUpstreamFields() throws {
        let json =
            #"{"text":"hello","thought":true,"thoughtSignature":"AQID","partMetadata":{"source":"test"},"speechMetadata":{},"toolCall":{"toolType":"TOOL_TYPE_UNSPECIFIED"}}"#
        let part = try JSONDecoder().decode(Components.Schemas.Part.self, from: Data(json.utf8))
        #expect(part.text == "hello")
        #expect(part.thought == true)
        #expect(part.thoughtSignature != nil)
        #expect(part.partMetadata != nil)
        #expect(part.speechMetadata != nil)
        #expect(part.toolCall != nil)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(part)) as! [String: Any]
        #expect(encoded["thoughtSignature"] as? String == "AQID")
        #expect(encoded["toolCall"] != nil)
    }

    @Test func apiKeyAppliesToGenerationAndFileOperations() async throws {
        let transport = StubTransport(
            check: { request, _, _ in
                #expect(request.headerFields[HTTPField.Name("x-goog-api-key")!] == "test-key")
            },
            json: "{}"
        )
        let client = Client(serverURL: serverURL, transport: transport, authentication: .apiKey("test-key"))
        _ = try await client.generateContent(path: .init(model: "test"), body: .json(.init(contents: [], model: "test")))
        _ = try await client.getFile(path: .init(file: "example"))
    }

    @Test func missingCredentialsFailBeforeTransport() async throws {
        let transport = StubTransport(
            check: { _, _, _ in
                Issue.record("Unauthenticated request reached transport")
            },
            json: "{}"
        )
        let client = Client(serverURL: serverURL, transport: transport, authentication: .none)
        do {
            _ = try await client.getFile(path: .init(file: "example"))
            Issue.record("Expected missing credentials to fail")
        } catch {
            #expect(String(describing: error).contains("unsatisfiedSecurityRequirements"))
        }
    }

    @Test func bearerAlternativeRemainsAvailable() async throws {
        let transport = StubTransport(
            check: { request, _, _ in
                #expect(request.headerFields[.authorization] == "Bearer access-token")
                #expect(request.headerFields[HTTPField.Name("x-goog-api-key")!] == nil)
            },
            json: "{}"
        )
        let client = Client(serverURL: serverURL, transport: transport, authentication: .bearer("access-token"))
        _ = try await client.getFile(path: .init(file: "example"))
    }

    @Test func bothFactoriesDecodeFractionalDates() async throws {
        let clients = [
            Client.urlSession(serverURL: serverURL, authentication: .apiKey("test"), middlewares: [StubResponse()]),
            Client.asyncHTTPClient(serverURL: serverURL, authentication: .apiKey("test"), middlewares: [StubResponse()]),
        ]
        for client in clients {
            let response = try await client.getFile(path: .init(file: "example"))
            let file = try response.default.body.json
            #expect(file.createTime != nil)
        }
    }

    @Test func factoriesRespectExplicitDateConfiguration() async throws {
        let configuration = Configuration(dateTranscoder: .iso8601)
        let clients = [
            Client.urlSession(serverURL: serverURL, configuration: configuration, middlewares: [StubResponse()]),
            Client.asyncHTTPClient(serverURL: serverURL, configuration: configuration, middlewares: [StubResponse()]),
        ]
        for client in clients {
            do {
                _ = try await client.getFile(path: .init(file: "example"))
                Issue.record("Strict ISO8601 override should reject fractional seconds")
            } catch {
                #expect(String(describing: error).contains("ISO8601"))
            }
        }
    }
}

private actor UploadTransport: ClientTransport {
    var requests = 0

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        requests += 1
        #expect(request.headerFields[HTTPField.Name("x-goog-api-key")!] == "test-key")
        if requests == 1 {
            #expect(request.headerFields[HTTPField.Name("x-goog-upload-header-content-type")!] == "image/png")
            #expect(request.headerFields[HTTPField.Name("x-goog-upload-header-content-length")!] == "3")
            #expect(request.headerFields[HTTPField.Name("x-goog-upload-command")!] == "start")
            return (
                HTTPResponse(
                    status: .ok,
                    headerFields: [
                        .contentType: "application/json",
                        HTTPField.Name("x-guploader-uploadid")!: "session-id",
                    ]
                ), HTTPBody("{}")
            )
        }
        #expect(request.path?.contains("upload_id=session-id") == true)
        #expect(request.headerFields[HTTPField.Name("x-goog-upload-command")!] == "upload, finalize")
        let bytes = try await Data(collecting: body!, upTo: 10)
        #expect(bytes == Data([1, 2, 3]))
        return (
            HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]),
            HTTPBody(#"{"file":{"uri":"https://example.com/file"}}"#)
        )
    }
}

extension GenerationRegressionTests {
    @Test func uploadUsesCallerMimeTypeAndSize() async throws {
        let transport = UploadTransport()
        let client = Client(
            serverURL: serverURL,
            transport: transport,
            authentication: .apiKey("test-key"),
            middlewares: [UnescapeGoogUploadHeadersMiddleware()]
        )
        let uri = try await uploadFileToGemini(client: client, fileData: HTTPBody(Data([1, 2, 3])), mimeType: "image/png", sizeBytes: 3)
        #expect(uri == "https://example.com/file")
        #expect(await transport.requests == 2)
    }

    @Test func streamingSupportsSSEAndJSON() async throws {
        let check: @Sendable (HTTPRequest, HTTPBody?, String) async throws -> Void = { request, _, _ in
            #expect(request.path?.contains("%24alt=sse") == true || request.path?.contains("$alt=sse") == true)
        }
        let sseClient = Client(
            serverURL: serverURL,
            transport: StubTransport(
                check: check,
                json: "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"hello\",\"thoughtSignature\":\"AQID\"}]}}]}\n\n",
                contentType: "text/event-stream"
            ),
            authentication: .apiKey("test")
        )
        let response = try await sseClient.streamGenerateContent(path: .init(model: "test"), query: .init(_dollar_alt: .sse), body: .json(.init(contents: [], model: "test")))
        let events = try response.default.body.textEventStream.asDecodedServerSentEventsWithJSONData(of: Components.Schemas.GenerateContentResponse.self)
        var count = 0
        for try await event in events {
            #expect(event.data?.candidates?.first?.content?.value1.parts?.first?.text == "hello")
            #expect(event.data?.candidates?.first?.content?.value1.parts?.first?.thoughtSignature != nil)
            count += 1
        }
        #expect(count == 1)
        let jsonClient = Client(serverURL: serverURL, transport: StubTransport(check: { _, _, _ in }, json: "[]"), authentication: .apiKey("test"))
        let jsonResponse = try await jsonClient.streamGenerateContent(path: .init(model: "test"), body: .json(.init(contents: [], model: "test")))
        #expect(try jsonResponse.default.body.json.isEmpty)
    }
}
