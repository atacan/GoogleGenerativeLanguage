import Foundation
import GoogleGenerativeLanguage
import GoogleGenerativeLanguageAsyncHTTPClient
import GoogleGenerativeLanguageTypes
import OpenAPIRuntime
import Testing

@Suite(.enabled(if: ProcessInfo.processInfo.environment["RUN_LIVE_TESTS"] == "1" && !(ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "").isEmpty))
struct TranscriptionLiveTests {
    @Test(.timeLimit(.minutes(5)))
    func transcribesWAVWithGemini35Transcribe() async throws {
        let environment = ProcessInfo.processInfo.environment
        let apiKey = try #require(environment["GEMINI_API_KEY"])
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let audioURL =
            environment["GEMINI_TRANSCRIPTION_AUDIO_PATH"].map { URL(fileURLWithPath: $0) }
            ?? packageRoot.appendingPathComponent("60s_speech.wav")
        let audio = try Data(contentsOf: audioURL)
        try #require(!audio.isEmpty, "The WAV fixture must contain audio")

        let client = Client.asyncHTTPClient(
            serverURL: try #require(URL(string: "https://generativelanguage.googleapis.com")),
            authentication: .apiKey(apiKey)
        )
        let response: Operations.CreateInteraction.Output
        do {
            response = try await client.createInteraction(
                path: .init(apiVersion: "v1beta"),
                headers: .init(accept: [.init(contentType: .json)]),
                body: .json(
                    .InteractionsCreateModelInteractionParams(
                        .init(
                            generationConfig: .init(
                                transcriptionConfig: .init(
                                    mode: .InteractionsTranscriptionMode(
                                        .InteractionsVerbatimTranscriptionMode(
                                            .init(diarizationMode: "speaker", timestampGranularities: ["word"], _type: .verbatim)
                                        )
                                    )
                                )
                            ),
                            input: .case3([
                                .InteractionsAudioContent(.init(data: Base64EncodedData(audio), mimeType: .audioWav, _type: .audio))
                            ]),
                            model: "gemini-3.5-transcribe",
                            store: false,
                            stream: false
                        )
                    )
                )
            )
        } catch {
            Issue.record("\(transcriptionLiveFailureDescription(error))")
            return
        }

        let interaction: Components.Schemas.InteractionsInteraction
        switch response {
        case .ok(let success):
            interaction = try success.body.json
        case .clientError(let status, _), .serverError(let status, _), .undocumented(let status, _):
            Issue.record("Live Interactions request returned HTTP \(status), expected HTTP 200")
            return
        }

        #expect(interaction.status == .completed)
        #expect(interaction.model == "gemini-3.5-transcribe")
        #expect(!interaction.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let words = interaction.wordAnnotations
        try #require(!words.isEmpty, "Verbatim transcription must include word annotations")
        #expect(words.contains { !($0.speaker ?? "").isEmpty })
        for word in words {
            let text = try #require(word.text)
            #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            let start = try #require(word.startOffset)
            let end = try #require(word.endOffset)
            try #require(start.hasSuffix("s") && end.hasSuffix("s"), "Word offsets must be duration strings")
            let startSeconds = try #require(Double(start.dropLast()))
            let endSeconds = try #require(Double(end.dropLast()))
            #expect(startSeconds >= 0)
            #expect(endSeconds >= startSeconds)
        }
    }
}

// ClientError descriptions include authenticated headers and the audio input.
// Report only status, error category, and coding path instead of dumping the error.
func transcriptionLiveFailureDescription(_ error: any Error) -> String {
    let clientError = error as? ClientError
    let cause = clientError?.underlyingError ?? error
    let status = clientError?.response.map { "HTTP \($0.status.code)" } ?? "no HTTP response"
    let detail: String
    switch cause {
    case DecodingError.keyNotFound(let key, let context):
        detail = "missing required key '\(key.stringValue)' at \(transcriptionCodingPath(context.codingPath))"
    case DecodingError.typeMismatch(let type, let context):
        detail = "expected \(type) at \(transcriptionCodingPath(context.codingPath))"
    case DecodingError.valueNotFound(let type, let context):
        detail = "missing \(type) value at \(transcriptionCodingPath(context.codingPath))"
    case DecodingError.dataCorrupted(let context):
        detail = "invalid encoded value at \(transcriptionCodingPath(context.codingPath))"
    default:
        detail = String(reflecting: type(of: cause))
    }
    return "Live Interactions request failed (\(status)): \(detail)"
}

private func transcriptionCodingPath(_ path: [any CodingKey]) -> String {
    (["$"] + path.map(\.stringValue)).joined(separator: ".")
}
