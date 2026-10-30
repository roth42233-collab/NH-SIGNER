import Foundation

struct CertificateModel: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var teamIdentifier: String
    var expirationDate: Date
    var p12FileName: String
    var provisionFileName: String
    var password: String
    var isRevoked: Bool = false
    var isSelected: Bool = false

    var isExpired: Bool {
        return Date() > expirationDate
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expirationDate)
        return max(0, components.day ?? 0)
    }

    var statusDescription: String {
        if isRevoked { return "Revoked" }
        if isExpired { return "Expired" }
        return "Valid (\(daysRemaining) days left)"
    }
}
