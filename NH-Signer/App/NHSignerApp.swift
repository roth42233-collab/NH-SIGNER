



import SwiftUI

@main
struct NHSignerApp: App {
    @StateObject private var certManager = CertificateManager.shared
    @StateObject private var otaServer = LocalOTAServer.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(certManager)
                .environmentObject(otaServer)
                .preferredColorScheme(.dark)
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }

            SignerView()
                .tabItem {
                    Label("Signer", systemImage: "signature")
                }

            LibraryView()
                .tabItem {
                    Label("Apps", systemImage: "shippingbox.fill")
                }

            CertificatesView()
                .tabItem {
                    Label("Certificates", systemImage: "checkmark.seal.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.cyan)
    }
}
