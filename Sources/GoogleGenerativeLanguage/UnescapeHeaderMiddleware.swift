import HTTPTypes
import OpenAPIRuntime

#if os(Linux)
@preconcurrency import struct Foundation.URL
@preconcurrency import struct Foundation.Data
@preconcurrency import struct Foundation.Date
#else
import struct Foundation.URL
import struct Foundation.Data
import struct Foundation.Date
#endif

public struct UnescapeGoogUploadHeadersMiddleware: ClientMiddleware {
    public init() {}
    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        if let httpFieldName = HTTPField.Name.init("X-Goog-Upload-Command") {
            request.headerFields[httpFieldName] = request.headerFields[httpFieldName]?.removingPercentEncoding
        }
        if let httpFieldName = HTTPField.Name.init("x-goog-upload-header-content-type") {
            request.headerFields[httpFieldName] = request.headerFields[httpFieldName]?.removingPercentEncoding
        }
        return try await next(request, body, baseURL)
    }
}
