import GoogleGenerativeLanguageTypes

extension Client {
    /// Transcribes an uploaded audio file using the beta Interactions API.
    ///
    /// Configure the client with Google's global endpoint. The returned resource
    /// retains word timestamps, speaker labels, usage, and all generated steps.
    public func transcribeAudio(
        fileURI: String,
        mimeType: Components.Schemas.InteractionsAudioContent.MimeTypePayload = .audioMpeg,
        configuration: Components.Schemas.InteractionsTranscriptionConfig? = nil,
        model: String = "gemini-3.5-transcribe"
    ) async throws -> Components.Schemas.InteractionsInteraction {
        let response = try await createInteraction(
            path: .init(apiVersion: "v1beta"),
            headers: .init(accept: [.init(contentType: .json)]),
            body: .json(
                .InteractionsCreateModelInteractionParams(
                    .init(
                        generationConfig: configuration.map { .init(transcriptionConfig: $0) },
                        input: .case3([.InteractionsAudioContent(.init(mimeType: mimeType, _type: .audio, uri: fileURI))]),
                        model: model,
                        stream: false
                    )
                )
            )
        )
        return try response.ok.body.json
    }
}
