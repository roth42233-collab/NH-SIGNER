import Foundation
import Security
import Combine

class CertificateManager: ObservableObject {
    static let shared = CertificateManager()

    @Published var certificates: [CertificateModel] = []
    @Published var activeCertificate: CertificateModel?

    private let storageKey = "NH_SIGNER_CERTIFICATES"

    private init() {
        loadCertificates()
    }

    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var certsDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("Certificates", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at, withIntermediateDirectories: true)
        }
        return dir
    }

    func loadCertificates() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([CertificateModel].self, from: data) else {
            return
        }
        self.certificates = list
        self.activeCertificate = list.first(where: { $0.isSelected }) ?? list.first
    }

    func saveCertificates() {
        if let data = try? JSONEncoder().encode(certificates) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func selectCertificate(_ cert: CertificateModel) {
        for i in certificates.indices {
            certificates[i].isSelected = (certificates[i].id == cert.id)
        }
        activeCertificate = certificates.first(where: { $0.id == cert.id })
        saveCertificates()
    }

    func deleteCertificate(at offsets: IndexSet) {
        for index in offsets {
            let cert = certificates[index]
            let p12URL = certsDirectory.appendingPathComponent(cert.p12FileName)
            let provURL = certsDirectory.appendingPathComponent(cert.provisionFileName)
            try? FileManager.default.removeItem(at: p12URL)
            try? FileManager.default.removeItem(at: provURL)
        }
        certificates.remove(atOffsets: offsets)
        if let active = activeCertificate, !certificates.contains(where: { $0.id == active.id }) {
            activeCertificate = certificates.first
        }
        saveCertificates()
    }

    func importCertificate(p12URL: URL, provisionURL: URL, password: String) -> Result<CertificateModel, Error> {
        do {
            let p12Data = try Data(contentsOf: p12URL)
            let provData = try Data(contentsOf: provisionURL)

            // Validate PKCS12 with Security framework
            let options: [String: Any] = [kSecImportExportPassphrase as String: password]
            var items: CFArray?
            let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)

            guard status == errSecSuccess else {
                return .failure(NSError(domain: "CertificateManager", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Invalid P12 password or corrupted certificate file"]))
            }

            // Parse MobileProvision plist embedded in ASN.1 CMS wrapper
            let (teamName, teamId, expiryDate) = parseMobileProvision(data: provData)

            let id = UUID()
            let p12DestName = "\(id.uuidString).p12"
            let provDestName = "\(id.uuidString).mobileprovision"

            try p12Data.write(to: certsDirectory.appendingPathComponent(p12DestName))
            try provData.write(to: certsDirectory.appendingPathComponent(provDestName))

            let cert = CertificateModel(
                id: id,
                name: teamName.isEmpty ? p12URL.deletingPathExtension().lastPathComponent : teamName,
                teamIdentifier: teamId,
                expirationDate: expiryDate ?? Date().addingTimeInterval(365 * 86400),
                p12FileName: p12DestName,
                provisionFileName: provDestName,
                password: password,
                isSelected: certificates.isEmpty
            )

            certificates.append(cert)
            if activeCertificate == nil {
                activeCertificate = cert
            }
            saveCertificates()
            return .success(cert)
        } catch {
            return .failure(error)
        }
    }

    private func parseMobileProvision(data: Data) -> (teamName: String, teamId: String, expiry: Date?) {
        guard let string = String(data: data, encoding: .ascii) else {
            return ("", "", nil)
        }

        var teamName = ""
        var teamId = ""
        var expiryDate: Date?

        if let startRange = string.range(of: "<?xml"),
           let endRange = string.range(of: "</plist>") {
            let plistString = String(string[startRange.lowerBound..<endRange.upperBound])
            if let plistData = plistString.data(using: .utf8),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                teamName = plist["TeamName"] as? String ?? ""
                if let teams = plist["TeamIdentifier"] as? [String], let first = teams.first {
                    teamId = first
                }
                expiryDate = plist["ExpirationDate"] as? Date
            }
        }

        return (teamName, teamId, expiryDate)
    }
}
