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

## Transcribe audio

The [beta Interactions schema](https://ai.google.dev/static/api/interactions.openapi.json) supplies the endpoint used by Google's [transcription guide](https://ai.google.dev/gemini-api/docs/transcribe#rest). Use the same client with the global server URL from `Servers.Server1.url()`:

```swift
let audio = try Data(contentsOf: URL(fileURLWithPath: "sample.mp3"))
let audioURI = try await uploadFileToGemini(
    client: client, fileData: HTTPBody(audio),
    mimeType: "audio/mpeg", sizeBytes: audio.count
)
let interaction = try await client.transcribeAudio(
    fileURI: audioURI,
    mimeType: .audioMpeg,
    configuration: .init(
        languageCodes: ["en-US"],
        mode: .InteractionsTranscriptionMode(.InteractionsVerbatimTranscriptionMode(.init(
            diarizationMode: "speaker", timestampGranularities: ["word"], _type: .verbatim
        )))
    )
)
print(interaction.outputText)
for word in interaction.wordAnnotations {
    print(word.text ?? "", word.speaker ?? "", word.startOffset ?? "", word.endOffset ?? "")
}
```

The helper defaults to `gemini-3.5-transcribe` and returns the full generated interaction. Omit `configuration` for default transcription. Smart transcription uses `configuration: .init(mode: .case2(.smart))`; language hints and custom vocabulary are also available in the typed configuration. Follow Google's documented constraints when combining features.

For direct access, `client.createInteraction(path: .init(apiVersion: "v1beta"), body: ...)` supports inline audio, other interaction inputs, typed error responses, and SSE with `stream: true`. Decode `response.ok.body.textEventStream` using `asDecodedServerSentEventsWithJSONData(of: Components.Schemas.InteractionsInteractionSseEvent.self)`. The transcription helper requests a JSON response; use the generated operation when you need streaming or direct status/error handling.

Interactions components carry an `Interactions` prefix, such as `Components.Schemas.InteractionsTranscriptionConfig`, to avoid collisions with Discovery types. Existing client products and transport factories serve both APIs. API-key or bearer credentials can authenticate Interactions operations; model strings accept the documented transcription model and future IDs.

## Regenerate

Install `uv`, Swift 6.2+, Python 3, curl, and Speakeasy's `openapi` CLI (`brew install openapi`). Then:

```sh
make prepare-openapi   # Download both official specs, sanitize, overlay, merge, generate
make download-openapi  # Only download and sort; no API key needed
make regenerate        # Regenerate from both checked-in source specs
make build
make test-offline
```

`make regenerate` uses bootstrapper commit `dacae24fb9bc4342f52a3638ac888d1ae45d5a13`, which includes automatic const-only tag inference from [generator PR #5](https://github.com/atacan/swift-package-generator-based-on-openapi/pull/5). The pinned commit keeps regeneration reproducible while that PR is open. To use the sibling development checkout, including its local changes:

```sh
make regenerate BOOTSTRAPPER='uv run --directory ../swift-package-generator-based-on-openapi swift-bootstrapper'
```

The downloaded sources and editable overlays live in `specifications/discovery/` and `specifications/interactions/`. `make regenerate` sanitizes and overlays each input independently, then `scripts/merge_openapi.py` combines them while preserving existing operation IDs and namespacing added components. It carries Interactions authentication onto each operation so the Discovery root security does not override it.

The root `original_openapi.json` is the generated combined bootstrapper input; `openapi.json` is its final sanitized output. Both are checked in with the generated Swift. Per-source intermediates live in ignored `.generation/`. Edit the overlays under `specifications/`; the root `openapi-overlay.json` intentionally has no actions. `generate`, `generate-openapi`, and `overlay-openapi` remain compatibility aliases for full regeneration.

The Discovery overlay retains API-key/OAuth/bearer alternatives, streaming responses, resumable uploads, a role enum, and relaxed model response requirements. The Interactions overlay makes Google's open model enum a string and maps Speakeasy authentication to API-key/bearer alternatives. The bootstrapper infers missing scalar types when converting `const` values, including Interactions union tags; tag typing needs no provider overlay. The Makefile also handles shell failures on macOS GNU Make 3.81. See [MIGRATION.md](MIGRATION.md) for source compatibility changes and validation notes.

Offline tests use stub responses and do not load API keys. The existing live tests require explicit opt-in with exported `RUN_LIVE_TESTS=1` and `GEMINI_API_KEY`; audio tests also need their local fixture paths updated. The migration did not run live API requests.

## License

MIT
