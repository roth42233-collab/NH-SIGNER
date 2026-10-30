import SwiftUI
import UniformTypeIdentifiers

struct CertificatesView: View {
    @EnvironmentObject var certManager: CertificateManager

    @State private var showingImporter = false
    @State private var importStep: ImportStep = .none
    @State private var selectedP12URL: URL?
    @State private var selectedProvisionURL: URL?
    @State private var password: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert = false

    enum ImportStep {
        case none
        case pickingP12
        case pickingProvision
        case enteringPassword
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Active & Saved Certificates")) {
                    if certManager.certificates.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No Certificates Found")
                                .font(.headline)
                            Text("Import a .p12 and .mobileprovision file using the + button below.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(certManager.certificates) { cert in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(cert.name)
                                            .font(.headline)
                                        if cert.isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.cyan)
                                        }
                                    }
                                    Text("Team ID: \(cert.teamIdentifier)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(cert.statusDescription)
                                        .font(.caption2)
                                        .foregroundColor(cert.isExpired ? .red : .green)
                                }
                                Spacer()
                                Button(action: {
                                    certManager.selectCertificate(cert)
                                }) {
                                    Text(cert.isSelected ? "Active" : "Use")
                                        .font(.caption)
                                        .bold()
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(cert.isSelected ? Color.cyan : Color.gray.opacity(0.3))
                                        .foregroundColor(cert.isSelected ? .black : .white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .onDelete(perform: certManager.deleteCertificate)
                    }
                }

                Section(header: Text("Instructions")) {
                    Text("1. Tap 'Import Certificate' button.")
                    Text("2. Select your Apple Development/Distribution .p12 file.")
                    Text("3. Select your matching .mobileprovision profile.")
                    Text("4. Enter certificate password to unlock.")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            .navigationTitle("Certificates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        importStep = .pickingP12
                        showingImporter = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingImporter) {
                DocumentPickerView(
                    step: importStep,
                    onPickP12: { url in
                        selectedP12URL = url
                        showingImporter = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            importStep = .pickingProvision
                            showingImporter = true
                        }
                    },
                    onPickProvision: { url in
                        selectedProvisionURL = url
                        showingImporter = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            importStep = .enteringPassword
                        }
                    }
                )
            }
            .sheet(isPresented: Binding(
                get: { importStep == .enteringPassword },
                set: { if !$0 { importStep = .none } }
            )) {
                PasswordInputView(password: $password) {
                    guard let p12 = selectedP12URL, let prov = selectedProvisionURL else { return }
                    let result = certManager.importCertificate(p12URL: p12, provisionURL: prov, password: password)
                    switch result {
                    case .success(let cert):
                        alertMessage = "Certificate '\(cert.name)' imported successfully!"
                        showAlert = true
                        importStep = .none
                    case .failure(let err):
                        alertMessage = "Import failed: \(err.localizedDescription)"
                        showAlert = true
                        importStep = .none
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Certificate Import"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct PasswordInputView: View {
    @Binding var password: String
    var onConfirm: () -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Certificate Password")) {
                    SecureField("Enter P12 Password", text: $password)
                }

                Section {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        onConfirm()
                    }) {
                        Text("Unlock & Import")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.cyan)
                            .bold()
                    }
                }
            }
            .navigationTitle("P12 Password")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let step: CertificatesView.ImportStep
    let onPickP12: (URL) -> Void
    let onPickProvision: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = (step == .pickingP12)
            ? [UTType(filenameExtension: "p12") ?? .data]
            : [UTType(filenameExtension: "mobileprovision") ?? .data]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            if parent.step == .pickingP12 {
                parent.onPickP12(url)
            } else {
                parent.onPickProvision(url)
            }
        }
    }
}
