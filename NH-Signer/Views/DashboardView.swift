import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var certManager: CertificateManager
    @EnvironmentObject var otaServer: LocalOTAServer

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Brand Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NH-SIGNER")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Independent iOS Sideloading Engine")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "bolt.shield.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )

                    // Active Certificate Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Active Certificate")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            if let cert = certManager.activeCertificate {
                                Text(cert.statusDescription)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(cert.isExpired ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                                    .foregroundColor(cert.isExpired ? .red : .green)
                                    .cornerRadius(8)
                            }
                        }

                        if let cert = certManager.activeCertificate {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(cert.name, systemImage: "signature")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Label("Team: \(cert.teamIdentifier)", systemImage: "person.crop.circle")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Label("Days left: \(cert.daysRemaining)", systemImage: "clock")
                                    .font(.footnote)
                                    .foregroundColor(.cyan)
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("No Certificate Imported")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Go to Certificates tab to import .p12 and .mobileprovision")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(18)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)

                    // Quick Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        StatCard(
                            title: "Certificates",
                            value: "\(certManager.certificates.count)",
                            icon: "checkmark.seal.fill",
                            color: .cyan
                        )
                        StatCard(
                            title: "OTA Server",
                            value: otaServer.isRunning ? "Port \(otaServer.port)" : "Offline",
                            icon: "antenna.radiowaves.left.and.right",
                            color: otaServer.isRunning ? .green : .orange
                        )
                    }

                    // Quick Action Guide
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features & Capabilities")
                            .font(.headline)
                            .foregroundColor(.white)

                        FeatureRow(icon: "shield.checkered", title: "Pure Native Swift", desc: "Zero heavy external packages or broken build scripts.")
                        FeatureRow(icon: "wifi", title: "Direct On-Device Install", desc: "Local loopback itms-services server for seamless installs.")
                        FeatureRow(icon: "lock.fill", title: "Security Framework", desc: "Hardware-accelerated PKCS12 parsing and verification.")
                    }
                    .padding(18)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.cyan)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}
