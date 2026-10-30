import SwiftUI
import UniformTypeIdentifiers

struct SignerView: View {
    @EnvironmentObject var certManager: CertificateManager
    @ObservedObject var signerService = IPASignerService.shared

    @State private var selectedIPAURL: URL?
    @State private var customName: String = ""
    @State private var customBundleId: String = ""
    @State private var customVersion: String = ""
    @State private var showFilePicker = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select IPA Package")) {
                    if let url = selectedIPAURL {
                        HStack {
                            Image(systemName: "app.gift.fill")
                                .font(.title)
                                .foregroundColor(.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(1)
                                Text("Ready to customize & sign")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            Button("Change") {
                                showFilePicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.cyan)
                        }
                    } else {
                        Button(action: {
                            showFilePicker = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.doc.fill")
                                    .foregroundColor(.cyan)
                                Text("Choose .ipa File from Device")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                Section(header: Text("App Customization (Optional)")) {
                    HStack {
                        Text("App Name")
                            .frame(width: 90, alignment: .leading)
                            .font(.subheadline)
                        TextField("Keep original name", text: $customName)
                    }

                    HStack {
                        Text("Bundle ID")
                            .frame(width: 90, alignment: .leading)
                            .font(.subheadline)
                        TextField("e.g. com.example.app", text: $customBundleId)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    HStack {
                        Text("Version")
                            .frame(width: 90, alignment: .leading)
                            .font(.subheadline)
                        TextField("1.0.0", text: $customVersion)
                    }
                }

                Section(header: Text("Signing Certificate")) {
                    if let cert = certManager.activeCertificate {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cert.name)
                                    .font(.subheadline.weight(.bold))
                                Text(cert.statusDescription)
                                    .font(.caption)
                                    .foregroundColor(cert.isExpired ? .red : .green)
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.cyan)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.orange)
                            Text("No certificate selected")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }

                if signerService.isSigning {
                    Section(header: Text("Signing Progress")) {
                        VStack(spacing: 8) {
                            ProgressView(value: signerService.progress, total: 1.0)
                                .accentColor(.cyan)
                            Text(signerService.statusMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button(action: startSigning) {
                        HStack {
                            Spacer()
                            if signerService.isSigning {
                                ProgressView()
                                    .padding(.trailing, 6)
                            }
                            Text(signerService.isSigning ? "Signing Application..." : "Sign Application")
                                .font(.body.weight(.bold))
                                .foregroundColor(canSign ? .cyan : .gray)
                            Spacer()
                        }
                    }
                    .disabled(!canSign || signerService.isSigning)
                }
            }
            .navigationTitle("Sign IPA")
            .sheet(isPresented: $showFilePicker) {
                IPAPickerView { url in
                    self.selectedIPAURL = url
                    if self.customName.isEmpty {
                        self.customName = url.deletingPathExtension().lastPathComponent
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Signing Result"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var canSign: Bool {
        return selectedIPAURL != nil && certManager.activeCertificate != nil
    }

    private func startSigning() {
        guard let url = selectedIPAURL, let cert = certManager.activeCertificate else { return }

        signerService.signIPA(
            sourceIPAURL: url,
            customName: customName.isEmpty ? nil : customName,
            customBundleId: customBundleId.isEmpty ? nil : customBundleId,
            customVersion: customVersion.isEmpty ? nil : customVersion,
            certificate: cert
        ) { result in
            switch result {
            case .success(let app):
                LibraryManager.shared.addApp(app)
                alertMessage = "Successfully signed '\(app.name)'! You can install it directly from the Apps library."
                showAlert = true
            case .failure(let err):
                alertMessage = "Signing error: \(err.localizedDescription)"
                showAlert = true
            }
        }
    }
}

struct IPAPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [UTType(filenameExtension: "ipa") ?? .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: IPAPickerView
        init(_ parent: IPAPickerView) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onPick(url)
            }
        }
    }
}
