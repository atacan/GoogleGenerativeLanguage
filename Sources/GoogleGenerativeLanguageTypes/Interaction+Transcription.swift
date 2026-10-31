extension Components.Schemas.InteractionsInteraction {
    /// Text produced by model-output steps, in response order.
    public var outputText: String {
        outputTextContents.map(\.text).joined()
    }

    /// Word annotations retain Google's speaker labels and duration strings.
    public var wordAnnotations: [Components.Schemas.InteractionsWordInfo] {
        outputTextContents.flatMap { text in
            (text.annotations ?? [])
                .compactMap { annotation in
                    guard case .InteractionsWordInfo(let word) = annotation else { return nil }
                    return word
                }
        }
    }

    private var outputTextContents: [Components.Schemas.InteractionsTextContent] {
        steps.flatMap { step -> [Components.Schemas.InteractionsTextContent] in
            guard case .InteractionsModelOutputStep(let output) = step else { return [] }
            return (output.content ?? [])
                .compactMap { content in
                    guard case .InteractionsTextContent(let text) = content else { return nil }
                    return text
                }
        }
    }
}
