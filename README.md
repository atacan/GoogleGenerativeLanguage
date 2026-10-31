# GoogleGenerativeLanguage

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fatacan%2FGoogleGenerativeLanguage%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/atacan/GoogleGenerativeLanguage)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fatacan%2FGoogleGenerativeLanguage%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/atacan/GoogleGenerativeLanguage)

A community Swift client generated from Google's [Gemini API](https://ai.google.dev/api) v1beta OpenAPI specification. The checked-in spec was refreshed on October 31, 2026; generation uses Swift OpenAPI Generator 1.14.3.

Requires Swift 6.2+ and iOS 16, macOS 13, watchOS 9, tvOS 16, or visionOS 1. Linux is also supported by the package dependencies; this migration was verified on macOS.

## Installation

Add the package dependency, then the core, types, and your chosen transport products:

```swift
.package(url: "https://github.com/atacan/GoogleGenerativeLanguage", from: "0.1.0")
```

```swift
.product(name: "GoogleGenerativeLanguage", package: "GoogleGenerativeLanguage"),
.product(name: "GoogleGenerativeLanguageTypes", package: "GoogleGenerativeLanguage"),
.product(name: "GoogleGenerativeLanguageURLSession", package: "GoogleGenerativeLanguage"),
```

Use `GoogleGenerativeLanguageAsyncHTTPClient` instead of the URLSession product for the other transport. The core client accepts any OpenAPI `ClientTransport`.

## Create a client

```swift
import Foundation
import GoogleGenerativeLanguage
import GoogleGenerativeLanguageTypes
import GoogleGenerativeLanguageURLSession

let client = Client.urlSession(
    serverURL: try Servers.Server1.url(),
    authentication: .apiKey("YOUR_API_KEY")
)
```

The AsyncHTTPClient factory returns the same `Client`:

```swift
import GoogleGenerativeLanguageAsyncHTTPClient

let client = Client.asyncHTTPClient(
    serverURL: try Servers.Server1.url(),
    authentication: .apiKey("YOUR_API_KEY")
)
// The existing convenience function now lives in this transport module:
let legacyClient = try createClient(apiKey: "YOUR_API_KEY")
```

Both factories decode fractional-second timestamps and correct upload header escaping. The AsyncHTTPClient factory and `createClient` retain a 20-minute timeout. Runtime configuration, transport configuration, and extra middleware can be supplied explicitly. Direct `Client(...)` initialization needs its own date configuration and upload middleware.

`.apiKey(...)` sends `x-goog-api-key`. `.bearer(...)` supports operations with an upstream bearer alternative; it does not supply an API key for API-key-only operations. The upstream OAuth schemes `google_oauth_code` and `google_oauth_implicit` require custom middleware and the original `Client` initializer. Static credentials and async credential providers are supported.

## Generate content

Choose an available model ID for your project:

```swift
let modelID = "YOUR_MODEL_ID"
let response = try await client.generateContent(
    path: .init(model: modelID),
    body: .json(.init(
        contents: [.init(parts: [.init(text: "Explain Swift concurrency")], role: .user)],
        model: modelID
    ))
)
let text = try response.default.body.json.candidates?.first?.content?.value1.parts?.first?.text
```

`Part` is Google's complete object model. Text, thought signatures, and media metadata can coexist. Reference properties retain the generator's `value1` wrappers, for example:

```swift
let part = Components.Schemas.Part(
    fileData: .init(value1: .init(fileUri: "YOUR_FILE_URI"))
)
```

## Stream content

```swift
let response = try await client.streamGenerateContent(
    path: .init(model: modelID),
    query: .init(_dollar_alt: .sse),
    body: .json(.init(
        contents: [.init(parts: [.init(text: "Write a poem")], role: .user)],
        model: modelID
    ))
)
let events = try response.default.body.textEventStream
    .asDecodedServerSentEventsWithJSONData(of: Components.Schemas.GenerateContentResponse.self)
for try await event in events {
    if let text = event.data?.candidates?.first?.content?.value1.parts?.first?.text {
        print(text, terminator: "")
    }
}
```

Without SSE, the streaming endpoint returns a JSON array. The overlay covers model, tuned-model, and dynamic streaming routes.

## Upload files

```swift
import OpenAPIRuntime

let data = try Data(contentsOf: URL(fileURLWithPath: "image.png"))
let uri = try await uploadFileToGemini(
    client: client, fileData: HTTPBody(data),
    mimeType: "image/png", sizeBytes: data.count
)
```

The helper starts a resumable session and uploads the bytes. The supplied MIME type and byte count are sent in upload headers; an omitted MIME type defaults to `application/octet-stream`.

## Regenerate

Install `uv`, Swift 6.2+, Python 3, curl, and Speakeasy's `openapi` CLI (`brew install openapi`). Then:

```sh
make prepare-openapi   # Download the latest spec, sanitize, overlay, generate
make download-openapi  # Only download and sort; no API key needed
make regenerate        # Regenerate from the checked-in source spec
make build
make test-offline
```

`make regenerate` runs the latest upstream bootstrapper. To use the sibling development checkout, including its local changes:

```sh
make regenerate BOOTSTRAPPER='uv run --directory ../swift-package-generator-based-on-openapi swift-bootstrapper'
```

`original_openapi.json` is the downloaded source; `openapi.json` and `Sources/*/GeneratedSources/` are generated. Edit `openapi-overlay.json` for Google-specific corrections. Regeneration starts from the original spec and preserves handwritten helpers and configuration. `generate`, `generate-openapi`, and `overlay-openapi` remain compatibility aliases for full regeneration.

The overlay adds missing API-key security while retaining OAuth/bearer alternatives, streaming response types and `sse`, the resumable upload operation, a role enum, and relaxed model response requirements. These are Google-specific semantics and should remain outside the general sanitizer. No common schema blocker required a new transformer. A general Makefile compatibility bug was fixed in the generator template: shell flags now work with macOS GNU Make 3.81, which ignores `.SHELLFLAGS`. See [MIGRATION.md](MIGRATION.md) for source compatibility changes and validation notes.

Offline tests use stub responses and do not load API keys. The existing live tests require explicit opt-in with exported `RUN_LIVE_TESTS=1` and `GEMINI_API_KEY`; audio tests also need their local fixture paths updated. The migration did not run live API requests.

## License

MIT
