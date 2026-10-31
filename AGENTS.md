We generate the Swift code using swift-openapi-generator. As we apply complex transformations to the original OpenAPI specification, we use a Python tool to do this. Run the generation with

```bash
make regenerate
```

As this is a Swift package, you can find the code of the Swift package dependencies in the ".build/checkouts/" directory. Look at that folder when you need to understand how to use the code from the Swift package dependencies.

The package exposes GoogleGenerativeLanguageTypes, GoogleGenerativeLanguage,
GoogleGenerativeLanguageURLSession, and GoogleGenerativeLanguageAsyncHTTPClient products.
Authentication belongs to the shared client target and is used by both transport
factories. Keep transport imports and dependencies out of the Types and shared
Client targets. Regenerate operation security metadata with `make regenerate`;
do not edit Authentication/GeneratedSecurity/OperationSecurity.swift directly.

## Troubleshooting response date decoding

If a client fails with `Expected date string to be ISO8601-formatted`, inspect the
response's timestamp format. Some APIs return fractional seconds, for example
`2024-11-24T10:33:18.185Z`. These responses can require the OpenAPI runtime setting
`configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds)`.

For an API using this format, set the provider-specific default in both
`Sources/GoogleGenerativeLanguageURLSession/Client+URLSession.swift` and
`Sources/GoogleGenerativeLanguageAsyncHTTPClient/Client+AsyncHTTPClient.swift`, so users
can create clients without discovering this setting themselves. Keep the public
`configuration:` parameter available and forward explicit caller overrides.
Check the API's actual format before changing defaults for another provider.

Direct generated `Client(...)` initialization bypasses convenience factory
defaults and may need an explicit date transcoder. Runtime configuration affects
HTTP conversion only; standalone `JSONDecoder` instances still need their own
`dateDecodingStrategy`. An archived JSON decoder helper is not required for the
generated client's HTTP conversion.

Keep factory edits outside `GeneratedSources/`; `make regenerate` preserves
existing helper files and AGENTS.md. After changing date defaults, run offline
response decoding tests for both factories and verify that explicit configuration
overrides still work. Run live tests only when authorized, without printing API
keys or reading them into test failure messages. Use the factory defaults in live
tests instead of repeating the date configuration at the call site.

## Google-specific regeneration

`make prepare-openapi` downloads the current public v1beta OpenAPI document without a key, then runs `make regenerate`. Keep the source at `original_openapi.json` and edits in `openapi-overlay.json`. Preserve upstream `Part` and `FunctionResponsePart`; do not restore the old closed Part union or model-ID enum. The overlay appends API-key alternatives without replacing OAuth/bearer alternatives and adds all three streaming response shapes plus the resumable upload path.

`createClient` belongs to the AsyncHTTPClient product. Both factories retain fractional-second dates and upload-header correction; the AsyncHTTPClient default timeout is 20 minutes. `make test-offline` runs stub-based regressions. Live tests require explicit `RUN_LIVE_TESTS=1` and an exported `GEMINI_API_KEY`, and must not be run during ordinary regeneration.
