import OpenAPIRuntime

/// Uploads a file to the Google Generative Language API and returns the file URI.
/// - Parameters:
///   - client: The client to use to upload the file.
///   - file: The file to upload.
///   - mimeType: The MIME type of the file.
///   - sizeBytes: The size of the file in bytes.
/// - Returns: The file URI.
public func uploadFileToGemini(client: Client, fileData: HTTPBody, mimeType: String?, sizeBytes: Int?) async throws -> String {

    // Step 1: Create upload session
    let sessionResponse = try await client.uploadFiles(
        headers: .init(
            xGoogUploadCommand: .start,
            xGoogUploadProtocol: .resumable,
            xGoogUploadHeaderContentType: .audioMpeg
        ),
        body: .json(
            .init(
                file: .init(
                    value1: .init(
                        mimeType: mimeType,
                        sizeBytes: sizeBytes.map { String($0) }
                    )
                )
            )
        )
    )

    // Extract upload ID from response headers
    guard let uploadID = try sessionResponse.ok.headers.xGUploaderUploadID else {
        throw UploadFileError.uploadIDNotFound
    }

    // Step 2: Upload the file data
    let uploadResponse = try await client.uploadFiles(
        query: .init(
            uploadId: uploadID,
            uploadProtocol: .resumable
        ),
        headers: .init(
            xGoogUploadCommand: .upload_comma_Finalize,
            xGoogUploadOffset: 0
        ),
        body: .binary(fileData)
    )

    guard let uri = try uploadResponse.ok.body.json.file?.value1.uri else {
        throw UploadFileError.fileURINotFound
    }

    return uri
}

public enum UploadFileError: Error {
    case uploadIDNotFound
    case fileURINotFound
}
