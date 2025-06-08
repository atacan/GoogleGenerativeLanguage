import Foundation

let thisFileUrl = URL(fileURLWithPath: #filePath)
let rootDirectoryUrl = thisFileUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let geminiApiKey = getEnvironmentVariable("GEMINI_API_KEY")!
let remoteOpenAPIUrl = URL(string: "https://generativelanguage.googleapis.com/$discovery/OPENAPI3_0?version=v1beta&key=\(geminiApiKey)")!
let originalOpenAPIUrl = rootDirectoryUrl.appendingPathComponent("assets/original.json")
let outputOpenAPIUrl = rootDirectoryUrl.appendingPathComponent("assets/openapi.json")

func saveOriginalOpenAPI() throws -> String {
    let originalOpenAPI = try! String(contentsOf: remoteOpenAPIUrl, encoding: .utf8)
    try originalOpenAPI.write(to: originalOpenAPIUrl, atomically: true, encoding: .utf8)
    print("Saved original OpenAPI to \(originalOpenAPIUrl.path())")
    // Format and sort
    try runCommand("openapi-format \(originalOpenAPIUrl.path()) -o \(originalOpenAPIUrl.path())")
    return originalOpenAPI
}

@main
struct PrepareMain {
    func runAll() throws {
        let originalOpenAPI = try saveOriginalOpenAPI()

        // Copy original OpenAPI to output path so it can be modified by the overlay tool
        try originalOpenAPI.write(to: outputOpenAPIUrl, atomically: true, encoding: .utf8)
        print("Copied original OpenAPI to \(outputOpenAPIUrl.path()) for modification")

        // Apply OpenAPI overlays
        try runCommand("make overlay-openapi")

        // Generate Swift code from OpenAPI
        try runCommand("make generate-openapi")
    }

    static func main() throws {
        try PrepareMain().runAll()
    }
}
