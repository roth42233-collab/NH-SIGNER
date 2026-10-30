import Foundation
import Combine

class LibraryManager: ObservableObject {
    static let shared = LibraryManager()

    @Published var signedApps: [AppModel] = []
    private let storageKey = "NH_SIGNER_SIGNED_APPS"

    private init() {
        loadApps()
    }

    func loadApps() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([AppModel].self, from: data) else {
            return
        }
        self.signedApps = list
    }

    func saveApps() {
        if let data = try? JSONEncoder().encode(signedApps) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func addApp(_ app: AppModel) {
        signedApps.insert(app, at: 0)
        saveApps()
    }

    func deleteApp(at offsets: IndexSet) {
        for index in offsets {
            let app = signedApps[index]
            try? FileManager.default.removeItem(atPath: app.filePath)
        }
        signedApps.remove(atOffsets: offsets)
        saveApps()
    }
}
