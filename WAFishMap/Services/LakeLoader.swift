import Foundation

/// Decodes the bundled WDFW lake list. Static, offline data, like `RiverLoader`.
enum LakeLoader {
    private struct File: Decodable {
        let lakes: [Lake]
    }

    static func lakes(from data: Data) throws -> [Lake] {
        try JSONDecoder().decode(File.self, from: data).lakes
    }
}
