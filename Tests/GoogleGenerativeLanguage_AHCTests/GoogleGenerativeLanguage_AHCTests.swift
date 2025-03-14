import Foundation
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
                )
            )
        )

        dump(response)
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
                    tools: [
                        .init(
                            functionDeclarations: [
                                f, f2
                            ]
                        )
                    ],
                    contents: [
                        .init(
                            parts: [
                                .init(text: "tell me the weather in Tokyo right now and also find what is the current population of Tokyo?")
                            ],
                            role: "user"
                        )
                    ],
                    model: "gemini-2.0-flash"
                )
            )
        )
        
        dump(response)
    }
}

func prettyEncode<T: Encodable>(_ thing: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    let data = try encoder.encode(thing)
    return String(data: data, encoding: .utf8)!
}

let f = Components.Schemas.FunctionDeclaration(
    parameters: .init(
        value1: Components.Schemas.Schema(
            properties: .init(
                additionalProperties: [
                    "city" : Components.Schemas.Schema(
                        description: "the city to find the weather for",
                        _type: .init(value1: .STRING)
                    )
                ]
            ),
            _type: .init(value1: .OBJECT),
        )
    ),
    name: "search_web",
    response: nil,
    description: "to search the web"
)

let f2 = Components.Schemas.FunctionDeclaration(
    parameters: .init(
        value1: Components.Schemas.Schema(
            properties: .init(
                additionalProperties: [
                    "search_term" : Components.Schemas.Schema(
                        description: "the keyword to search for",
                        _type: .init(value1: .STRING)
                    ),
                    "search_engine": Components.Schemas.Schema(
                        description: "where to search", _type: .init(value1: .STRING),
                        _enum: ["google", "bing", "yahoo"]
                    )
                ]
            ),
            _type: .init(value1: .OBJECT),
        )
    ),
    name: "search_web",
    response: nil,
    description: "to search the web"
)
