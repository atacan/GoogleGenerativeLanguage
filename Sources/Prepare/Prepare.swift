import Foundation
import OrderedCollections

let thisFileUrl = URL(fileURLWithPath: #filePath)
let rootDirectoryUrl = thisFileUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let geminiApiKey = getEnvironmentVariable("GEMINI_API_KEY")!
let remoteOpenAPIUrl = URL(string: "https://generativelanguage.googleapis.com/$discovery/OPENAPI3_0?version=v1beta&key=\(geminiApiKey)")!
let originalOpenAPIUrl = rootDirectoryUrl.appendingPathComponent("assets/original.json")
let outputOpenAPIUrl = rootDirectoryUrl.appendingPathComponent("assets/openapi.json")

func saveOriginalOpenAPI() throws -> String {
    let originalOpenAPI = try! String(contentsOf: remoteOpenAPIUrl, encoding: .utf8)
    
    // Parse JSON and sort schema properties
    let sortedOpenAPI = try sortOpenAPISchemaProperties(originalOpenAPI)
    
    try sortedOpenAPI.write(to: originalOpenAPIUrl, atomically: true, encoding: .utf8)
    print("Saved original OpenAPI to \(originalOpenAPIUrl.path())")

    return sortedOpenAPI
}

func sortOpenAPISchemaProperties(_ jsonString: String) throws -> String {
    let jsonData = jsonString.data(using: .utf8)!
    let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
    
    let sortedObject = sortJSONObject(jsonObject)
    
    let sortedData = try JSONSerialization.data(withJSONObject: sortedObject, options: [.prettyPrinted, .sortedKeys])
    return String(data: sortedData, encoding: .utf8)!
}

func sortJSONObject(_ object: Any) -> Any {
    if let dictionary = object as? [String: Any] {
        var sortedDict = OrderedDictionary<String, Any>()
        
        // Sort keys alphabetically
        let sortedKeys = dictionary.keys.sorted()
        
        for key in sortedKeys {
            let value = dictionary[key]!
            
            // Special handling for schema objects - sort their properties
            if key == "schemas" {
                if let schemas = value as? [String: Any] {
                    var sortedSchemas = OrderedDictionary<String, Any>()
                    let sortedSchemaKeys = schemas.keys.sorted()
                    
                    for schemaKey in sortedSchemaKeys {
                        sortedSchemas[schemaKey] = sortSchemaObject(schemas[schemaKey]!)
                    }
                    var regularDict = [String: Any]()
                    for (schemaKey, schemaValue) in sortedSchemas {
                        regularDict[schemaKey] = schemaValue
                    }
                    sortedDict[key] = regularDict
                } else {
                    sortedDict[key] = sortJSONObject(value)
                }
            } else {
                sortedDict[key] = sortJSONObject(value)
            }
        }
        
        var regularDict = [String: Any]()
        for (key, value) in sortedDict {
            regularDict[key] = value
        }
        return regularDict
    } else if let array = object as? [Any] {
        return array.map { sortJSONObject($0) }
    } else {
        return object
    }
}

func sortSchemaObject(_ object: Any) -> Any {
    if let dictionary = object as? [String: Any] {
        var sortedDict = OrderedDictionary<String, Any>()
        
        // Sort keys alphabetically
        let sortedKeys = dictionary.keys.sorted()
        
        for key in sortedKeys {
            let value = dictionary[key]!
            
            // Special handling for properties within a schema
            if key == "properties" {
                if let properties = value as? [String: Any] {
                    var sortedProperties = OrderedDictionary<String, Any>()
                    let sortedPropertyKeys = properties.keys.sorted()
                    
                    for propKey in sortedPropertyKeys {
                        sortedProperties[propKey] = sortJSONObject(properties[propKey]!)
                    }
                    var regularDict = [String: Any]()
                    for (propKey, propValue) in sortedProperties {
                        regularDict[propKey] = propValue
                    }
                    sortedDict[key] = regularDict
                } else {
                    sortedDict[key] = sortJSONObject(value)
                }
            } else {
                sortedDict[key] = sortJSONObject(value)
            }
        }
        
        var regularDict = [String: Any]()
        for (key, value) in sortedDict {
            regularDict[key] = value
        }
        return regularDict
    } else if let array = object as? [Any] {
        return array.map { sortSchemaObject($0) }
    } else {
        return object
    }
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
