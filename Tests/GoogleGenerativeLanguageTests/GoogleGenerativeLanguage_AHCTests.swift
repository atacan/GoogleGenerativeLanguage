import CustomDump
import Foundation
import GoogleGenerativeLanguage
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import Testing

#if os(Linux)
@preconcurrency import struct Foundation.URL
@preconcurrency import struct Foundation.Data
@preconcurrency import struct Foundation.Date
#else
import struct Foundation.URL
import struct Foundation.Data
import struct Foundation.Date
#endif

struct GoogleGenerativeLanguageTestsTests {

    let client = {
        let apiKey = getEnvironmentVariable("GEMINI_API_KEY")!
        let serverURL = try! Servers.Server1.url()

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
    }()

    @Test
    func simpleRequest() async throws {
        let response = try await client.generateContent(
            path: .init(model: "gemini-2.0-flash"),
            // query: .init(_dollar_alt: Components.Parameters.alt?, _dollar_callback: Components.Parameters.callback?, _dollar_prettyPrint: Components.Parameters.prettyPrint?, _dollar__period_xgafv: Components.Parameters.__period_xgafv?),
            // headers: Operations.GenerateContent.Input.Headers,
            body: .json(
                .init(
                    contents: [
                        .init(
                            parts: [
                                .TextPart(.init(text: "tell me the weather in Tokyo right now and also find what is the current population of Tokyo?"))
                            ],
                            role: .user
                        )
                    ],
                    model: "gemini-2.0-flash",
                    tools: [
                        .init(
                            googleSearch: .init(value1: .init())
                            //                            codeExecution: .init(value1: .init())
                            //                            googleSearchRetrieval: .init(value1: .init())
                            //                            functionDeclarations: []
                        )
                    ]
                )
            )
        )

        customDump(response)
    }

    @Test
    func streamingResponse() async throws {
        let response = try await client.streamGenerateContent(
            path: .init(model: Components.Schemas.ModelID.gemini2_0Flash.rawValue),
            query: .init(_dollar_alt: .sse),
            body: .json(
                .init(
                    contents: [
                        .init(
                            parts: [.TextPart(.init(text: "Write me a long poem about the Swift programming language's compilation speed"))],
                            role: .user
                        )
                    ],
                    model: Components.Schemas.ModelID.gemini2_0Flash.rawValue
                )
            )
        )

        let stream = try response.default.body.textEventStream
            .asDecodedServerSentEventsWithJSONData(of: Components.Schemas.GenerateContentResponse.self)

        for try await event in stream {
            switch event.data?.candidates?.first?.content?.value1.parts?.first {
            case .TextPart(let textPart):
                print(textPart.text, terminator: "")
            default:
                break
            }
        }
    }

    @Test
    func encodeFunctionDeclarations() async throws {

        try print(prettyEncode(f2))
    }

    @Test func functionDeclarations() async throws {
        let response = try await client.generateContent(
            path: .init(model: Components.Schemas.ModelID.gemini2_0Flash.rawValue),
            body: .json(
                .init(
                    contents: [
                        .init(
                            parts: [
                                .TextPart(.init(text: "tell me the weather in Tokyo right now and also find what is the current population of Tokyo?"))
                            ],
                            role: .user
                        )
                    ],
                    model: Components.Schemas.ModelID.gemini2_0Flash.rawValue,
                    tools: [
                        .init(
                            functionDeclarations: [
                                f, f2,
                            ]
                        )
                    ]
                )
            )
        )

        try customDump(response.default.body.json)
    }

    @Test func transcribeAudio() async throws {
        let audioData = try Data(contentsOf: URL(fileURLWithPath: "/Users/atacan/Developer/Repositories/GoogleGenerativeLanguage/assets/speech.mp3"))
        let modelID = Components.Schemas.ModelID.gemini2_5FlashPreview0520.rawValue
        let response = try await client.generateContent(
            path: .init(model: modelID),
            body: .json(
                .init(
                    contents: [
                        .init(
                            parts: [
                                .InlineDataPart(
                                    .init(
                                        inlineData: .init(
                                            data: Base64EncodedData(audioData),
                                            mimeType: "audio/mpeg"
                                        )
                                    )
                                ),
                                .TextPart(.init(text: "transcribe the audio")),
                            ],
                            role: .user
                        )
                    ],
                    model: modelID
                )
            )
        )
        try customDump(response.default.body.json.candidates?.first?.content?.value1.parts)
    }

    @Test func uploadFile() async throws {
        let file = try Data(contentsOf: URL(fileURLWithPath: "/Users/atacan/Developer/Repositories/GoogleGenerativeLanguage/assets/speech.mp3"))

        // Step 1: Create upload session
        let sessionResponse = try await client.uploadFiles(
            headers: .init(
                xGoogUploadCommand: .start,
                xGoogUploadProtocol: .resumable,
                xGoogUploadHeaderContentType: .audioMpeg
            ),
            body: .json(
                .init(
                    file: .init(
                        value1: .init(
                            mimeType: "audio/mpeg",
                            sizeBytes: String(file.count)
                        )
                    )
                )
            )
        )

        // Extract upload ID from response headers
        guard let uploadID = try sessionResponse.ok.headers.xGUploaderUploadID else {
            throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Upload ID not found in response"])
        }

        // Step 2: Upload the file data
        let uploadResponse = try await client.uploadFiles(
            query: .init(
                uploadId: uploadID,
                uploadProtocol: .resumable
            ),
            headers: .init(
                xGoogUploadCommand: .upload_comma_Finalize,
                xGoogUploadOffset: 0
            ),
            body: .binary(HTTPBody(file))
        )

        customDump(uploadResponse)

        guard let uri = try uploadResponse.ok.body.json.file?.value1.uri else {
            throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "File URI not found in response"])
        }

        let modelID = Components.Schemas.ModelID.gemini2_5FlashPreview0520.rawValue
        let response = try await client.generateContent(
            path: .init(model: modelID),
            body: .json(
                .init(
                    contents: [
                        .init(
                            parts: [
                                .TextPart(
                                    Components.Schemas.TextPart(text: "describe the audio")
                                ),
                                .FileDataPart(.init(fileData: .init(fileUri: uri)))
                            ],
                            role: .user
                        )
                    ],
                    model: modelID
                )
            )
        )
        try customDump(response.default.body.json)
    }
}

func prettyEncode<T: Encodable>(_ thing: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    let data = try encoder.encode(thing)
    return String(data: data, encoding: .utf8)!
}

let f = Components.Schemas.FunctionDeclaration(
    description: "get the weather in a city",
    name: "get_weather",
    parameters: .init(
        value1: Components.Schemas.Schema(
            properties: .init(
                additionalProperties: [
                    "city": Components.Schemas.Schema(
                        description: "the city to find the weather for",
                        _type: .init(value1: .string)
                    )
                ]
            ),
            _type: .init(value1: .object),
        )
    ),
    response: nil
)

let f2 = Components.Schemas.FunctionDeclaration(
    description: "to search the web",
    name: "search_web",
    parameters: .init(
        value1: Components.Schemas.Schema(
            properties: .init(
                additionalProperties: [
                    "search_term": Components.Schemas.Schema(
                        description: "the keyword to search for",
                        _type: .init(value1: .string)
                    ),
                    "search_engine": Components.Schemas.Schema(
                        description: "where to search",
                        _enum: ["google", "bing", "yahoo"],
                        _type: .init(value1: .string)
                    ),
                ],
            ),
            required: ["search_term", "search_engine"],
            _type: .init(value1: .object)
        )
    ),
    response: nil
)
