import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var otaServer: LocalOTAServer

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App Information")) {
                    HStack {
                        Text("Application")
                        Spacer()
                        Text("NH-Signer iOS")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Author")
                        Spacer()
                        Text("NH-TEAM")
                            .foregroundColor(.cyan)
                    }
                }

                Section(header: Text("Local Installation Server")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(otaServer.isRunning ? "Online" : "Offline")
                            .foregroundColor(otaServer.isRunning ? .green : .red)
                    }

                    HStack {
                        Text("Port")
                        Spacer()
                        Text("\(otaServer.port)")
                            .foregroundColor(.gray)
                    }

                    Button(action: {
                        if otaServer.isRunning {
                            otaServer.stop()
                        } else {
                            otaServer.start()
                        }
                    }) {
                        Text(otaServer.isRunning ? "Restart Server" : "Start Server")
                            .foregroundColor(.cyan)
                    }
                }

                Section(header: Text("Community & Support")) {
                    Link(destination: URL(string: "https://t.me/nh_nak")!) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                            Text("Telegram Channel")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/roth42233-collab/NH-SIGNER")!) {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundColor(.purple)
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section(footer: Text("NH-Signer is a native standalone iOS signing tool built for swift sideloading and zero external dependencies.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
        }
    }
}
