import SwiftUI
import UniformTypeIdentifiers

struct CertificatesView: View {
    @EnvironmentObject var certManager: CertificateManager
    @State private var showingImportModal = false

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
                            Text("Tap the '+' button at the top right to import your .p12 and .mobileprovision certificate.")
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
                                        .font(.caption.weight(.bold))
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
                    Text("1. Tap the '+' button at the top right.")
                    Text("2. Choose your .p12 and .mobileprovision files.")
                    Text("3. Enter password (if any) and tap 'Unlock & Import'.")
                    Text("4. Once imported, it will automatically be selected for signing.")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            .navigationTitle("Certificates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingImportModal = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingImportModal) {
                ImportCertificateSheet(isPresented: $showingImportModal)
                    .environmentObject(certManager)
            }
        }
    }
}

struct ImportCertificateSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var certManager: CertificateManager

    @State private var p12URL: URL?
    @State private var provisionURL: URL?
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isProcessing = false

    @State private var pickingType: PickerTarget?

    enum PickerTarget: Identifiable {
        case p12
        case provision
        var id: Int { hashValue }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("1. Select Certificate Files")) {
                    // P12 row
                    Button(action: {
                        pickingType = .p12
                    }) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(p12URL != nil ? .green : .cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p12URL?.lastPathComponent ?? "Choose .p12 File")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text(p12URL != nil ? "Ready" : "PKCS12 Certificate")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: p12URL != nil ? "checkmark.circle.fill" : "chevron.right")
                                .foregroundColor(p12URL != nil ? .green : .gray)
                        }
                    }

                    // Mobileprovision row
                    Button(action: {
                        pickingType = .provision
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.gearshape.fill")
                                .foregroundColor(provisionURL != nil ? .green : .cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provisionURL?.lastPathComponent ?? "Choose .mobileprovision File")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text(provisionURL != nil ? "Ready" : "Provisioning Profile")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: provisionURL != nil ? "checkmark.circle.fill" : "chevron.right")
                                .foregroundColor(provisionURL != nil ? .green : .gray)
                        }
                    }
                }

                Section(header: Text("2. Certificate Password")) {
                    SecureField("Enter P12 password (blank if none)", text: $password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                if !errorMessage.isEmpty {
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section {
                    Button(action: processImport) {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isProcessing ? "Verifying..." : "Unlock & Import Certificate")
                                .font(.body.weight(.bold))
                                .foregroundColor(canImport ? .cyan : .gray)
                            Spacer()
                        }
                    }
                    .disabled(!canImport || isProcessing)
                }
            }
            .navigationTitle("Import Certificate")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
            )
            .sheet(item: $pickingType) { target in
                SingleDocumentPicker(target: target) { fileURL in
                    if target == .p12 {
                        p12URL = fileURL
                    } else {
                        provisionURL = fileURL
                    }
                    errorMessage = ""
                }
            }
        }
    }

    private var canImport: Bool {
        return p12URL != nil && provisionURL != nil
    }

    private func processImport() {
        guard let p12 = p12URL, let prov = provisionURL else { return }
        isProcessing = true
        errorMessage = ""

        DispatchQueue.global(qos: .userInitiated).async {
            let result = certManager.importCertificate(p12URL: p12, provisionURL: prov, password: password)

            DispatchQueue.main.async {
                isProcessing = false
                switch result {
                case .success:
                    isPresented = false
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }
}

struct SingleDocumentPicker: UIViewControllerRepresentable {
    let target: ImportCertificateSheet.PickerTarget
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = (target == .p12)
            ? [UTType(filenameExtension: "p12") ?? .data]
            : [UTType(filenameExtension: "mobileprovision") ?? .data]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: SingleDocumentPicker

        init(_ parent: SingleDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            let isScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let tempDir = FileManager.default.temporaryDirectory
            let targetURL = tempDir.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")

            do {
                let data = try Data(contentsOf: url)
                try data.write(to: targetURL)
                DispatchQueue.main.async {
                    self.parent.onPick(targetURL)
                }
            } catch {
                print("Error copying picked file: \(error)")
            }
        }
    }
}
