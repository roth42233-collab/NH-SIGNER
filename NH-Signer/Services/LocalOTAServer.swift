import Foundation
import Network
import Combine

class LocalOTAServer: ObservableObject {
    static let shared = LocalOTAServer()

    @Published var isRunning: Bool = false
    @Published var port: UInt16 = 8088
    @Published var tunnelURL: String = UserDefaults.standard.string(forKey: "NH_TUNNEL_URL") ?? "" {
        didSet {
            UserDefaults.standard.set(tunnelURL, forKey: "NH_TUNNEL_URL")
        }
    }

    private var listener: NWListener?
    private var ipaDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("SignedApps", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {
        start()
    }

    func start() {
        guard !isRunning else { return }
        do {
            let parameters = NWParameters.tcp
            self.listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: self.port) ?? 8088)
            self.listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                    case .failed, .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }

            self.listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            self.listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            print("Failed to start local OTA server: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, _ in
            guard let self = self, let data = data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let lines = request.components(separatedBy: "\r\n")
            guard let firstLine = lines.first else {
                connection.cancel()
                return
            }

            let parts = firstLine.components(separatedBy: " ")
            guard parts.count >= 2 else {
                connection.cancel()
                return
            }

            let path = parts[1]
            self.routeRequest(path: path, connection: connection)
        }
    }

    private func routeRequest(path: String, connection: NWConnection) {
        if path.starts(with: "/manifest.plist") {
            // Serve generated manifest
            let query = URLComponents(string: "http://127.0.0.1\(path)")?.queryItems
            let appName = query?.first(where: { $0.name == "name" })?.value ?? "NH-App"
            let bundleId = query?.first(where: { $0.name == "bundle" })?.value ?? "com.nhsigner.app"
            let file = query?.first(where: { $0.name == "file" })?.value ?? "app.ipa"

            let manifest = generateManifest(appName: appName, bundleId: bundleId, fileName: file)
            sendResponse(connection: connection, contentType: "text/xml", body: manifest.data(using: .utf8) ?? Data())
        } else if path.starts(with: "/download/") {
            // Serve IPA binary
            let fileName = path.replacingOccurrences(of: "/download/", with: "")
            let decoded = fileName.removingPercentEncoding ?? fileName
            let fileURL = ipaDirectory.appendingPathComponent(decoded)

            if let fileData = try? Data(contentsOf: fileURL) {
                sendResponse(connection: connection, contentType: "application/octet-stream", body: fileData)
            } else {
                sendNotFound(connection: connection)
            }
        } else {
            sendNotFound(connection: connection)
        }
    }

    private func sendResponse(connection: NWConnection, contentType: String, body: Data) {
        let headers = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var responseData = headers.data(using: .utf8) ?? Data()
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    private func sendNotFound(connection: NWConnection) {
        let text = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: text.data(using: .utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    func generateInstallURL(app: AppModel) -> URL? {
        let nameEncoded = app.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "App"
        let bundleEncoded = app.bundleIdentifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "com.app"
        let fileEncoded = URL(fileURLWithPath: app.filePath).lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        var baseURL = "http://127.0.0.1:\(port)"
        let trimmedTunnel = tunnelURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTunnel.isEmpty {
            baseURL = trimmedTunnel.hasSuffix("/") ? String(trimmedTunnel.dropLast()) : trimmedTunnel
        }

        let manifestURL = "\(baseURL)/manifest.plist?name=\(nameEncoded)&bundle=\(bundleEncoded)&file=\(fileEncoded)"
        let manifestEncoded = manifestURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? manifestURL
        return URL(string: "itms-services://?action=download-manifest&url=\(manifestEncoded)")
    }

    private func generateManifest(appName: String, bundleId: String, fileName: String) -> String {
        var baseURL = "http://127.0.0.1:\(port)"
        let trimmedTunnel = tunnelURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTunnel.isEmpty {
            baseURL = trimmedTunnel.hasSuffix("/") ? String(trimmedTunnel.dropLast()) : trimmedTunnel
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>items</key>
            <array>
                <dict>
                    <key>assets</key>
                    <array>
                        <dict>
                            <key>kind</key>
                            <string>software-package</string>
                            <key>url</key>
                            <string>\(baseURL)/download/\(fileName)</string>
                        </dict>
                    </array>
                    <key>metadata</key>
                    <dict>
                        <key>bundle-identifier</key>
                        <string>\(bundleId)</string>
                        <key>bundle-version</key>
                        <string>1.0</string>
                        <key>kind</key>
                        <string>software</string>
                        <key>title</key>
                        <string>\(appName)</string>
                    </dict>
                </dict>
            </array>
        </dict>
        </plist>
        """
    }
}
