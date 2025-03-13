import GoogleGenerativeLanguage_AHC
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import Testing

@testable import GoogleGenerativeLanguage_AHC

#if os(Linux)
@preconcurrency import struct Foundation.URL
@preconcurrency import struct Foundation.Data
@preconcurrency import struct Foundation.Date
#else
import struct Foundation.URL
import struct Foundation.Data
import struct Foundation.Date
#endif

struct GoogleGenerativeLanguage_AHCTestsTests {

    let client = {
        let apiKey = getEnvironmentVariable("GEMINI_API_KEY")!
        let serverURL = try! Servers.Server1.url()

        let client = Client(
            serverURL: serverURL,
            transport: AsyncHTTPClientTransport(),
            middlewares: [
                AuthenticationMiddleware(apiKey: apiKey)
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
                    tools: [
                        .init(
                            googleSearch: .init(value1: .init())
//                            codeExecution: .init(value1: .init())
//                            googleSearchRetrieval: .init(value1: .init())
//                            functionDeclarations: []
                        )
                    ],
                    contents: [
                        .init(
                            parts: [
                                .init(
                                    text: "What is the best feature of dictop app? Take a look at dictop.com"
                                )
                            ],
                            role: "user"
                        )
                    ],
                    model: "gemini-2.0-flash"
//                    generationConfig: .init(
//                        value1: .init(
//                            topK: <#T##Int32?#>,
//                            responseLogprobs: <#T##Bool?#>,
//                            candidateCount: <#T##Int32?#>,
//                            logprobs: <#T##Int32?#>,
//                            stopSequences: <#T##[String]?#>,
//                            enableEnhancedCivicAnswers: <#T##Bool?#>,
//                            responseModalities: <#T##Components.Schemas.GenerationConfig.responseModalitiesPayload?#>,
//                            responseMimeType: <#T##String?#>,
//                            seed: <#T##Int32?#>,
//                            topP: <#T##Float?#>,
//                            mediaResolution: <#T##Components.Schemas.GenerationConfig.mediaResolutionPayload?#>,
//                            temperature: <#T##Float?#>,
//                            frequencyPenalty: <#T##Float?#>,
//                            presencePenalty: <#T##Float?#>,
//                            maxOutputTokens: <#T##Int32?#>,
//                            speechConfig: <#T##Components.Schemas.GenerationConfig.speechConfigPayload?#>,
//                            responseSchema: <#T##Components.Schemas.GenerationConfig.responseSchemaPayload?#>
//                        )
//                    )
                )
            )
        )
        
        dump(response)
    }
}
