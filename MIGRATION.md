# October 2026 generation migration

- Removed the `Prepare` executable and its `OrderedCollections` dependency. Make now downloads the public Discovery OpenAPI document without credentials, validates and sorts JSON in temporary files, and replaces the source spec only after success.
- Moved the source spec and overlay from `assets/` to `original_openapi.json` and `openapi-overlay.json`. The old generator configuration is replaced by separate Types and Client configurations with idiomatic naming.
- Adopted the generator's four products: Types, core Client, URLSession, and AsyncHTTPClient. Consumers must import Types for `Components`, `Operations`, and `Servers`, and the relevant transport module for factories. `createClient(apiKey:timeout:)` now belongs to `GoogleGenerativeLanguageAsyncHTTPClient`.
- Replaced the legacy `AuthenticationMiddleware(apiKey:)` with shared operation-aware authentication. Use `.apiKey(...)` or `AuthenticationMiddleware(authentication: .apiKey(...))`. Missing required credentials now fail before transport.
- Removed the fixed `Part` union and its custom branch models. It lost new upstream fields, treated signatures/video metadata as mutually exclusive payloads, and collided with Google's new `FunctionResponsePart`. Use `.init(text: ...)` instead of `.TextPart(.init(text: ...))`; use `.init(fileData: .init(value1: ...))` for referenced payloads. Signatures and other metadata can accompany content.
- Removed the stale `ModelID` enum; use model ID strings supplied by the caller. Review upstream removals as well: the refreshed spec removes several old chunk/search schemas and adds batch, environment, and file-search APIs.
- Upload MIME types are unrestricted strings. `xGoogUploadHeaderContentType: .audioMpeg` becomes `xGoogUploadHeaderContentType: "audio/mpeg"`. The upload helper now forwards the caller's MIME type and byte count.
- Requires Swift 6.2+ because the resolved generator requires that toolchain. The migration used Swift 6.4.2, bootstrapper 0.3.0 at upstream commit `021134f`, and Swift OpenAPI Generator 1.14.3. The first run used the sibling checkout including its pre-existing uncommitted `op15_remove_fields` transformer; the final regeneration and idempotence check used the latest upstream tool through the default Make command. The sibling transformer changes were left untouched.

## Overlay ownership

API-key declarations, streaming content types, Google upload headers/paths, and output-only response requirements require provider knowledge. Keep these in the Google overlay. The automatic sanitizer compiled this spec without an additional common schema transformation. A separate general Makefile bug was reproduced and fixed in the bootstrapper template: macOS GNU Make 3.81 ignores `.SHELLFLAGS`, so flags must be carried in `SHELL` to stop recipes on errors, failed pipelines, and unset variables. The download failure-path check now confirms that invalid specs leave the source unchanged and clean up temporary files. In particular, globally converting optional object properties into a `oneOf` would invent exclusivity and repeat the old `Part` problem.

Google's original file/cached-content operations include OAuth/bearer alternatives but omit the API-key option used by Gemini. The overlay appends API-key alternatives to existing security arrays and sets a root requirement for new/custom operations. It retains the upstream alternatives. Future regeneration should review any new security requirements rather than assuming the source's empty arrays are intentional public access.

Both factories preserve fractional-second dates, upload-header unescaping, and explicit configuration overrides. The AsyncHTTPClient default remains 20 minutes. Handwritten helpers live outside generated directories and survive reruns.

## Validation

Run `make build` and `make test-offline`. Regression tests cover Part metadata round trips, API-key and bearer alternatives, missing credentials, both factories' fractional dates and explicit overrides, SSE/JSON streaming, and the resumable upload request sequence with a non-audio MIME type. Live tests remain opt-in.

The source/overlay relocation used srcmv plan `sha256:8ceb9c59691f852e1b2568cb2d0da519c65aa0418ce67bb67c55935eb38f8800`. The transaction committed with complete recoverability; both destination hashes matched the source bytes before the separate download and overlay edits. The tool warned that metadata beyond content bytes and POSIX permission bits is not preserved.
