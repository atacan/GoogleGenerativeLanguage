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
        let response = try await client.GenerateContent(
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
        let response = try await client.StreamGenerateContent(
            path: .init(model: "gemini-2.0-flash"),
            query: .init(_dollar_alt: .sse),
            body: .json(
                .init(
                    contents: [
                        .init(
                            parts: [.TextPart(.init(text: "Write me a long poem about the Swift programming language's compilation speed"))],
                            role: .user
                        )
                    ],
                    model: "gemini-2.0-flash"
                )
            )
        )

        let stream = try response.default.body.text_event_hyphen_stream
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
        let response = try await client.GenerateContent(
            path: .init(model: "gemini-2.0-flash"),
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
        let modelID = Components.Schemas.ModelID.gemini_hyphen_2_period_5_hyphen_flash_hyphen_preview_hyphen_05_hyphen_20.rawValue
        let response = try await client.GenerateContent(
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
        let sessionResponse = try await client.UploadFiles(
            headers: .init(
                X_hyphen_Goog_hyphen_Upload_hyphen_Command: .start,
                X_hyphen_Goog_hyphen_Upload_hyphen_Protocol: .resumable,
                X_hyphen_Goog_hyphen_Upload_hyphen_Header_hyphen_Content_hyphen_Length: file.count,
                X_hyphen_Goog_hyphen_Upload_hyphen_Header_hyphen_Content_hyphen_Type: .audio_sol_mpeg
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
        guard let uploadID = try sessionResponse.ok.headers.X_hyphen_GUploader_hyphen_UploadID else {
            throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Upload ID not found in response"])
        }

        // Step 2: Upload the file data
        let uploadResponse = try await client.UploadFiles(
            query: .init(
                upload_id: uploadID,
                upload_protocol: .resumable
            ),
            headers: .init(
                X_hyphen_Goog_hyphen_Upload_hyphen_Command: .upload_comma__space_finalize,
                X_hyphen_Goog_hyphen_Upload_hyphen_Offset: 0
            ),
            body: .binary(HTTPBody(file))
        )

        customDump(uploadResponse)

        guard let uri = try uploadResponse.ok.body.json.file?.value1.uri else {
            throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "File URI not found in response"])
        }

        let modelID = Components.Schemas.ModelID.gemini_hyphen_2_period_5_hyphen_flash_hyphen_preview_hyphen_05_hyphen_20.rawValue
        let response = try await client.GenerateContent(
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
                        _type: .init(value1: .STRING)
                    )
                ]
            ),
            _type: .init(value1: .OBJECT),
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
                        _type: .init(value1: .STRING)
                    ),
                    "search_engine": Components.Schemas.Schema(
                        description: "where to search",
                        _enum: ["google", "bing", "yahoo"],
                        _type: .init(value1: .STRING)
                    ),
                ],
            ),
            required: ["search_term", "search_engine"],
            _type: .init(value1: .OBJECT)
        )
    ),
    response: nil
)
