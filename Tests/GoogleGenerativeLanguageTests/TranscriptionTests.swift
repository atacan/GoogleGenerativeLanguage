import Foundation
import GoogleGenerativeLanguage
import GoogleGenerativeLanguageTypes
import HTTPTypes
import OpenAPIRuntime
import Testing

private let transcriptionResponse = #"""
    {
      "id": "interactions/example", "status": "completed", "model": "gemini-3.5-transcribe",
      "created": "2026-10-31T12:00:00Z", "updated": "2026-10-31T12:00:01Z",
      "steps": [
        {"type":"user_input","content":[{"type":"audio","uri":"https://example.com/audio"}]},
        {"type":"model_output","content":[{"type":"text","text":"Hello world","annotations":[
          {"type":"word_info","text":"Hello","speaker":"spk_1","start_offset":"0.100s","end_offset":"0.400s"},
          {"type":"word_info","text":"world","speaker":"spk_1","start_offset":"0.500s","end_offset":"0.800s"}
        ]}]},
        {"type":"model_output","content":[{"type":"text","text":"!"}]}
      ]
    }
    """#

private struct TranscriptionTransport: ClientTransport {
    var check: @Sendable (HTTPRequest, HTTPBody?) async throws -> Void = { _, _ in }
    var response: String = transcriptionResponse
    var contentType: String = "application/json"
    var status: HTTPResponse.Status = .ok

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(operationID == "CreateInteraction")
        try await check(request, body)
        return (HTTPResponse(status: status, headerFields: [.contentType: contentType]), HTTPBody(response))
    }
}

private func requestJSON(_ body: HTTPBody?) async throws -> [String: Any] {
    let data = try await Data(collecting: #require(body), upTo: 100_000)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

struct TranscriptionTests {
    private let serverURL = URL(string: "https://generativelanguage.googleapis.com")!

    @Test func transcriptionUsesBetaRouteAndAPIKeyWithSmartConfiguration() async throws {
        let transport = TranscriptionTransport(check: { request, body in
            #expect(request.method == .post)
            #expect(request.path == "/v1beta/interactions")
            #expect(request.headerFields[HTTPField.Name("x-goog-api-key")!] == "test-key")
            #expect(request.headerFields[.authorization] == nil)
            #expect(request.headerFields[.accept] == "application/json")
            let json = try await requestJSON(body)
            #expect(json["model"] as? String == "gemini-3.5-transcribe")
            #expect(json["stream"] as? Bool == false)
            let input = try #require(json["input"] as? [[String: Any]])
            #expect(input.first?["type"] as? String == "audio")
            #expect(input.first?["uri"] as? String == "https://example.com/audio")
            #expect(input.first?["mime_type"] as? String == "audio/mp3")
            let generation = try #require(json["generation_config"] as? [String: Any])
            let config = try #require(generation["transcription_config"] as? [String: Any])
            #expect(config["language_codes"] as? [String] == ["en-US"])
            #expect(config["custom_vocabulary"] as? [String] == ["Swift"])
            #expect(config["mode"] as? String == "smart")
        })
        let client = Client(serverURL: serverURL, transport: transport, authentication: .apiKey("test-key"))
        let result = try await client.transcribeAudio(
            fileURI: "https://example.com/audio",
            mimeType: .audioMp3,
            configuration: .init(customVocabulary: ["Swift"], languageCodes: ["en-US"], mode: .case2(.smart))
        )
        #expect(result.outputText == "Hello world!")
        #expect(result.wordAnnotations.map(\.text) == ["Hello", "world"])
        #expect(result.wordAnnotations.first?.speaker == "spk_1")
        #expect(result.wordAnnotations.first?.startOffset == "0.100s")
        #expect(result.wordAnnotations.last?.endOffset == "0.800s")
    }

    @Test func verbatimSupportsDiarizationAndWordTimestamps() async throws {
        let transport = TranscriptionTransport(check: { _, body in
            let json = try await requestJSON(body)
            let generation = try #require(json["generation_config"] as? [String: Any])
            let config = try #require(generation["transcription_config"] as? [String: Any])
            let mode = try #require(config["mode"] as? [String: Any])
            #expect(mode["type"] as? String == "verbatim")
            #expect(mode["diarization_mode"] as? String == "speaker")
            #expect(mode["timestamp_granularities"] as? [String] == ["word"])
        })
        let client = Client(serverURL: serverURL, transport: transport, authentication: .apiKey("test"))
        _ = try await client.transcribeAudio(
            fileURI: "https://example.com/audio",
            configuration: .init(
                mode: .InteractionsTranscriptionMode(
                    .InteractionsVerbatimTranscriptionMode(
                        .init(
                            diarizationMode: "speaker",
                            timestampGranularities: ["word"],
                            _type: .verbatim
                        )
                    )
                )
            )
        )
    }

    @Test func bearerCredentialsAndFutureModelStringsAreSupported() async throws {
        let transport = TranscriptionTransport(
            check: { request, body in
                #expect(request.headerFields[.authorization] == "Bearer test-token")
                #expect(request.headerFields[HTTPField.Name("x-goog-api-key")!] == nil)
                let json = try await requestJSON(body)
                #expect(json["model"] as? String == "future-transcription-model")
            },
            response: transcriptionResponse.replacingOccurrences(of: "gemini-3.5-transcribe", with: "future-transcription-model")
        )
        let client = Client(serverURL: serverURL, transport: transport, authentication: .bearer("test-token"))
        let result = try await client.transcribeAudio(fileURI: "https://example.com/audio", model: "future-transcription-model")
        #expect(result.model == "future-transcription-model")
    }

    @Test func missingCredentialsFailBeforeSendingTranscription() async throws {
        let transport = TranscriptionTransport(check: { _, _ in Issue.record("Request reached transport without credentials") })
        let client = Client(serverURL: serverURL, transport: transport, authentication: .none)
        do {
            _ = try await client.transcribeAudio(fileURI: "https://example.com/audio")
            Issue.record("Expected authentication failure")
        } catch {
            #expect(String(describing: error).contains("unsatisfiedSecurityRequirements"))
        }
    }

    @Test func typedTagsPreserveStepsAndAnnotationsOnRoundTrip() throws {
        let interaction = try JSONDecoder().decode(Components.Schemas.InteractionsInteraction.self, from: Data(transcriptionResponse.utf8))
        guard case .InteractionsModelOutputStep(let output) = interaction.steps[1],
            case .InteractionsTextContent(let text) = output.content?.first,
            case .InteractionsWordInfo(let word) = text.annotations?.first
        else {
            Issue.record("Incorrect union branch decoded")
            return
        }
        #expect(word.text == "Hello")
        let encoded = try JSONEncoder().encode(interaction)
        let decoded = try JSONDecoder().decode(Components.Schemas.InteractionsInteraction.self, from: encoded)
        #expect(decoded.outputText == interaction.outputText)
        #expect(decoded.wordAnnotations == interaction.wordAnnotations)
    }

    @Test func lowLevelInteractionsSupportsSSE() async throws {
        let transport = TranscriptionTransport(
            check: { _, body in
                let json = try await requestJSON(body)
                #expect(json["stream"] as? Bool == true)
            },
            response:
                "event: interaction.completed\ndata: {\"event_type\":\"interaction.completed\",\"interaction\":{\"id\":\"example\",\"model\":\"gemini-3.5-transcribe\",\"status\":\"completed\"}}\n\n",
            contentType: "text/event-stream"
        )
        let client = Client(serverURL: serverURL, transport: transport, authentication: .apiKey("test"))
        let response = try await client.createInteraction(
            path: .init(apiVersion: "v1beta"),
            body: .json(
                .InteractionsCreateModelInteractionParams(
                    .init(
                        input: .case3([.InteractionsAudioContent(.init(_type: .audio, uri: "https://example.com/audio"))]),
                        model: "gemini-3.5-transcribe",
                        stream: true
                    )
                )
            )
        )
        let events = try response.ok.body.textEventStream.asDecodedServerSentEventsWithJSONData(of: Components.Schemas.InteractionsInteractionSseEvent.self)
        var count = 0
        for try await event in events {
            guard case .InteractionsInteractionCompletedEvent(let completed) = event.data else {
                Issue.record("Expected a completion event")
                continue
            }
            #expect(completed.interaction.id == "example")
            #expect(completed.interaction.model == "gemini-3.5-transcribe")
            count += 1
        }
        #expect(count == 1)
    }

    @Test func lowLevelAPIKeepsTypedErrorResponses() async throws {
        let transport = TranscriptionTransport(response: #"{"error":{"code":"invalid_argument","message":"bad audio"}}"#, status: .badRequest)
        let client = Client(serverURL: serverURL, transport: transport, authentication: .apiKey("test"))
        let response = try await client.createInteraction(
            path: .init(apiVersion: "v1beta"),
            body: .json(.InteractionsCreateModelInteractionParams(.init(input: .case4("test"), model: "gemini-3.5-transcribe")))
        )
        guard case .clientError(let code, let failure) = response else {
            Issue.record("Expected a typed client error")
            return
        }
        #expect(code == 400)
        #expect(try failure.body.json.error.message == "bad audio")
    }
}
