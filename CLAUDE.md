@AGENTS.md

## Google-specific regeneration

`make prepare-openapi` downloads the current public v1beta OpenAPI document without a key, then runs `make regenerate`. Keep the source at `original_openapi.json` and edits in `openapi-overlay.json`. Preserve upstream `Part` and `FunctionResponsePart`; do not restore the old closed Part union or model-ID enum. The overlay appends API-key alternatives without replacing OAuth/bearer alternatives and adds all three streaming response shapes plus the resumable upload path.

`createClient` belongs to the AsyncHTTPClient product. Both factories retain fractional-second dates and upload-header correction; the AsyncHTTPClient default timeout is 20 minutes. `make test-offline` runs stub-based regressions. Live tests require explicit `RUN_LIVE_TESTS=1` and an exported `GEMINI_API_KEY`, and must not be run during ordinary regeneration.
