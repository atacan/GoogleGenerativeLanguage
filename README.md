# GoogleGenerativeLanguage

A community-driven Swift SDK for the [Google Generative Language API](https://ai.google.dev/) (Gemini). Google does not provide an official Swift SDK -- this package fills that gap.

Auto-generated from Google's OpenAPI spec using [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator), so every endpoint and type stays in sync with the upstream API.

## Features

- Full coverage of the Generative Language API v1beta (79 endpoints)
- Text generation and streaming responses (SSE)
- Multimodal inputs -- text, images, audio, video, files
- Function calling / tool use
- Embeddings (single and batch)
- File uploads with resumable protocol
- Cached content for cost optimization
- Semantic search via corpora, documents, and chunks
- Model fine-tuning
- Token counting
- Built with Swift concurrency (`async`/`await`, `Sendable`)

## Requirements

- Swift 6.1+
- iOS 16.0+ / macOS 13.0+ / watchOS 9.0+ / tvOS 16.0+ / visionOS 1.0+
- Linux is also supported

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atacan/GoogleGenerativeLanguage", from: "0.1.0"),
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "GoogleGenerativeLanguage", package: "GoogleGenerativeLanguage"),
    ]
)
```

## Quick Start

### Create a Client

```swift
import GoogleGenerativeLanguage

let client = try createClient(apiKey: "YOUR_API_KEY")
```

### Generate Content

```swift
let response = try await client.generateContent(
    path: .init(model: "gemini-2.0-flash"),
    body: .json(
        .init(
            contents: [
                .init(
                    parts: [.TextPart(.init(text: "Explain quantum computing in one paragraph"))],
                    role: .user
                )
            ],
            model: "gemini-2.0-flash"
        )
    )
)

let text = try response.default.body.json.candidates?.first?
    .content?.value1.parts?.first
// .TextPart contains the generated text
```

### Streaming Responses

```swift
let response = try await client.streamGenerateContent(
    path: .init(model: "gemini-2.0-flash"),
    query: .init(_dollar_alt: .sse),
    body: .json(
        .init(
            contents: [
                .init(
                    parts: [.TextPart(.init(text: "Write a poem about Swift"))],
                    role: .user
                )
            ],
            model: "gemini-2.0-flash"
        )
    )
)

let stream = try response.default.body.textEventStream
    .asDecodedServerSentEventsWithJSONData(of: Components.Schemas.GenerateContentResponse.self)

for try await event in stream {
    if case .TextPart(let part) = event.data?.candidates?.first?.content?.value1.parts?.first {
        print(part.text, terminator: "")
    }
}
```

### Function Calling

```swift
let weatherFunction = Components.Schemas.FunctionDeclaration(
    description: "Get the weather in a city",
    name: "get_weather",
    parameters: .init(
        value1: .init(
            properties: .init(
                additionalProperties: [
                    "city": .init(
                        description: "The city to get weather for",
                        _type: .init(value1: .string)
                    )
                ]
            ),
            required: ["city"],
            _type: .init(value1: .object)
        )
    ),
    response: nil
)

let response = try await client.generateContent(
    path: .init(model: "gemini-2.0-flash"),
    body: .json(
        .init(
            contents: [
                .init(
                    parts: [.TextPart(.init(text: "What's the weather in Tokyo?"))],
                    role: .user
                )
            ],
            model: "gemini-2.0-flash",
            tools: [.init(functionDeclarations: [weatherFunction])]
        )
    )
)
```

### File Upload

```swift
import Foundation
import OpenAPIRuntime

let fileData = try Data(contentsOf: URL(fileURLWithPath: "audio.mp3"))
let uri = try await uploadFileToGemini(
    client: client,
    fileData: HTTPBody(fileData),
    mimeType: "audio/mpeg",
    sizeBytes: fileData.count
)

// Use the uploaded file in a request
let response = try await client.generateContent(
    path: .init(model: "gemini-2.0-flash"),
    body: .json(
        .init(
            contents: [
                .init(
                    parts: [
                        .FileDataPart(.init(fileData: .init(fileUri: uri))),
                        .TextPart(.init(text: "Describe this audio")),
                    ],
                    role: .user
                )
            ],
            model: "gemini-2.0-flash"
        )
    )
)
```

### Google Search Grounding

```swift
let response = try await client.generateContent(
    path: .init(model: "gemini-2.0-flash"),
    body: .json(
        .init(
            contents: [
                .init(
                    parts: [.TextPart(.init(text: "What happened in the news today?"))],
                    role: .user
                )
            ],
            model: "gemini-2.0-flash",
            tools: [.init(googleSearch: .init(value1: .init()))]
        )
    )
)
```

## How It Works

The SDK is generated from Google's official [Generative Language API OpenAPI specification](https://generativelanguage.googleapis.com/$discovery/rest?version=v1beta&key=placeholder). The generation pipeline:

1. Fetches the latest OpenAPI spec from Google's Discovery Service
2. Applies overlays and formatting
3. Generates Swift client code using [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator)

This means the SDK is always a faithful representation of the API surface -- no hand-written wrappers that can drift out of date.

## API Key

Get your API key from [Google AI Studio](https://aistudio.google.com/apikey).

## License

MIT
