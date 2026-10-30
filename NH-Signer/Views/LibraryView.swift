import SwiftUI

struct LibraryView: View {
    @ObservedObject var libraryManager = LibraryManager.shared
    @EnvironmentObject var otaServer: LocalOTAServer

    @State private var shareURL: URL?
    @State private var isSharing = false

    var body: some View {
        NavigationView {
            List {
                if libraryManager.signedApps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 44))
                            .foregroundColor(.gray)
                        Text("No Signed Apps")
                            .font(.headline)
                        Text("Apps you sign will appear here ready to install or share.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ForEach(libraryManager.signedApps) { app in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(.cyan)
                                    .padding(.trailing, 4)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(app.bundleIdentifier)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    HStack {
                                        Text("v\(app.version)")
                                        Text("•")
                                        Text(app.formattedSize)
                                        Text("•")
                                        Text(app.formattedDate)
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                }
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                Button(action: {
                                    installApp(app)
                                }) {
                                    Label("Install", systemImage: "arrow.down.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(Color.cyan)
                                        .foregroundColor(.black)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    shareApp(app)
                                }) {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.3))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete(perform: libraryManager.deleteApp)
                }
            }
            .navigationTitle("Signed Apps")
            .sheet(isPresented: $isSharing) {
                if let url = shareURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
    }

    private func installApp(_ app: AppModel) {
        if let installURL = otaServer.generateInstallURL(app: app) {
            UIApplication.shared.open(installURL, options: [:], completionHandler: nil)
        }
    }

    private func shareApp(_ app: AppModel) {
        let url = URL(fileURLWithPath: app.filePath)
        if FileManager.default.fileExists(atPath: url.path) {
            shareURL = url
            isSharing = true
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
