import Foundation

struct AppModel: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var bundleIdentifier: String
    var version: String
    var buildNumber: String
    var filePath: String
    var originalFileName: String
    var signedDate: Date
    var fileSize: Int64
    var iconData: Data?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: signedDate)
    }
}
