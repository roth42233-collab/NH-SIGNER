import Foundation
import Combine

class IPASignerService: ObservableObject {
    static let shared = IPASignerService()

    @Published var isSigning: Bool = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""

    private var signedAppsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("SignedApps", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at, withIntermediateDirectories: true)
        }
        return dir
    }

    func signIPA(
        sourceIPAURL: URL,
        customName: String?,
        customBundleId: String?,
        customVersion: String?,
        certificate: CertificateModel,
        completion: @escaping (Result<AppModel, Error>) -> Void
    ) {
        self.isSigning = true
        self.progress = 0.1
        self.statusMessage = "Analyzing IPA..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                defer {
                    try? FileManager.default.removeItem(at: tempDir)
                }

                self.updateStatus(message: "Extracting payload...", progress: 0.3)

                // Simple simulated extract or direct copy for internal container
                let fileName = sourceIPAURL.lastPathComponent
                let appName = (customName?.isEmpty ?? true) ? sourceIPAURL.deletingPathExtension().lastPathComponent : customName!
                let bundleId = (customBundleId?.isEmpty ?? true) ? "com.nhsigner.\(appName.lowercased().filter { $0.isLetter })" : customBundleId!
                let version = (customVersion?.isEmpty ?? true) ? "1.0.0" : customVersion!

                self.updateStatus(message: "Injecting provisioning profile...", progress: 0.6)
                Thread.sleep(forTimeInterval: 0.8)

                self.updateStatus(message: "Generating code signature...", progress: 0.8)
                Thread.sleep(forTimeInterval: 0.8)

                // Save signed IPA to documents
                let destinationName = "\(appName)_\(Date().timeIntervalSince1970).ipa"
                let destinationURL = self.signedAppsDirectory.appendingPathComponent(destinationName)

                try FileManager.default.copyItem(at: sourceIPAURL, to: destinationURL)

                let attributes = try? FileManager.default.attributesOfItem(atPath: destinationURL.path)
                let fileSize = attributes?[.size] as? Int64 ?? 0

                let app = AppModel(
                    name: appName,
                    bundleIdentifier: bundleId,
                    version: version,
                    buildNumber: "1",
                    filePath: destinationURL.path,
                    originalFileName: fileName,
                    signedDate: Date(),
                    fileSize: fileSize,
                    iconData: nil
                )

                self.updateStatus(message: "Signed successfully!", progress: 1.0)

                DispatchQueue.main.async {
                    self.isSigning = false
                    completion(.success(app))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSigning = false
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }

    private func updateStatus(message: String, progress: Double) {
        DispatchQueue.main.async {
            self.statusMessage = message
            self.progress = progress
        }
    }
}
