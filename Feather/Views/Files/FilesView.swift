//
//  FilesView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers
import Zip

struct FilesView: View {
	@Environment(\.scenePhase) private var scenePhase
	
	// Root documents directory
	private let rootDirectory: URL = {
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL.documentsDirectory
	}()
	
	// State
	@State private var currentDirectory: URL
	@State private var directoryStack: [URL] = []
	@State private var items: [FileItem] = []
	@State private var searchText: String = ""
	@State private var selectedScope: FileScope = .all
	
	// Modals & Sheets
	@State private var isImportingPresenting = false
	@State private var isDownloadURLPresenting = false
	@State private var downloadURLString = ""
	@State private var isCreateFolderPresenting = false
	@State private var newFolderName = ""
	
	// Actions State
	@State private var fileToRename: FileItem? = nil
	@State private var newFileName = ""
	@State private var isRenameAlertPresenting = false
	
	@State private var fileToDelete: FileItem? = nil
	@State private var isDeleteAlertPresenting = false
	
	@State private var certToImport: FileItem? = nil
	@State private var certPassword = ""
	@State private var isCertPasswordAlertPresenting = false
	
	@State private var isProcessing = false
	@State private var alertTitle = ""
	@State private var alertMessage = ""
	@State private var isStatusAlertPresenting = false
	
	init() {
		let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL.documentsDirectory
		_currentDirectory = State(initialValue: root)
	}
	
	// Filtered items
	private var filteredItems: [FileItem] {
		items.filter { item in
			let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
			guard matchesSearch else { return false }
			
			switch selectedScope {
			case .all:
				return true
			case .ipas:
				return item.isIPA
			case .certificates:
				return item.isCertificate || item.isProvision
			case .archives:
				return item.isArchive
			case .folders:
				return item.isDirectory
			}
		}
	}
	
	var body: some View {
		NBNavigationView(directoryStack.isEmpty ? "" : currentDirectory.lastPathComponent, displayMode: .inline) {
			VStack(spacing: 0) {
				// File List
				List {
					if !directoryStack.isEmpty {
						_backFolderRow()
					}
					
					ForEach(filteredItems) { item in
						FileCellView(
							item: item,
							onSelect: _handleItemSelect,
							onImportToLibrary: _importIPAToLibrary,
							onImportCertificate: _promptImportCertificate,
							onImportProvision: _importProvisionFile,
							onUnzip: _unzipArchive,
							onRename: _promptRename,
							onDelete: _promptDelete,
							onShare: _shareFile
						)
					}
				}
				.listStyle(.insetGrouped)
				.refreshable {
					_loadDirectoryContents()
				}
				.searchable(text: $searchText, prompt: .localized("Search Files"))
				.overlay {
					if filteredItems.isEmpty {
						_emptyStateView()
					}
				}
				
				// Footer Info Bar
				_storageFooter()
			}
			.toolbar {
				if !directoryStack.isEmpty {
					ToolbarItem(placement: .topBarLeading) {
						Button {
							_navigateBack()
						} label: {
							HStack(spacing: 4) {
								Image(systemName: "chevron.left")
									.font(.system(size: 16, weight: .semibold))
								Text(directoryStack.last?.lastPathComponent ?? .localized("Back"))
									.font(.system(size: 16))
							}
						}
					}
				}
				
				ToolbarItem(placement: .topBarTrailing) {
					_toolbarMenu()
				}
			}
			.sheet(isPresented: $isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.item],
					allowsMultipleSelection: true,
					onDocumentsPicked: _handleDocumentsPicked
				)
				.ignoresSafeArea()
			}
			.alert(.localized("Download from URL"), isPresented: $isDownloadURLPresenting) {
				TextField("https://example.com/app.ipa", text: $downloadURLString)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled(true)
				Button(.localized("Cancel"), role: .cancel) {
					downloadURLString = ""
				}
				Button(.localized("Download")) {
					_downloadFromURL()
				}
			}
			.alert(.localized("New Folder"), isPresented: $isCreateFolderPresenting) {
				TextField(.localized("Folder Name"), text: $newFolderName)
				Button(.localized("Cancel"), role: .cancel) {
					newFolderName = ""
				}
				Button(.localized("Create")) {
					_createNewFolder()
				}
			}
			.alert(.localized("Rename"), isPresented: $isRenameAlertPresenting) {
				TextField(.localized("New Name"), text: $newFileName)
				Button(.localized("Cancel"), role: .cancel) {
					fileToRename = nil
					newFileName = ""
				}
				Button(.localized("Save")) {
					_performRename()
				}
			}
			.alert(.localized("Delete File"), isPresented: $isDeleteAlertPresenting) {
				Button(.localized("Cancel"), role: .cancel) {
					fileToDelete = nil
				}
				Button(.localized("Delete"), role: .destructive) {
					_performDelete()
				}
			} message: {
				if let file = fileToDelete {
					Text(.localized("Are you sure you want to delete '\(file.name)'? This action cannot be undone."))
				}
			}
			.alert(.localized("Import Certificate"), isPresented: $isCertPasswordAlertPresenting) {
				SecureField(.localized("Enter Password (Optional)"), text: $certPassword)
				Button(.localized("Cancel"), role: .cancel) {
					certToImport = nil
					certPassword = ""
				}
				Button(.localized("Import")) {
					_performImportCertificate()
				}
			} message: {
				Text(.localized("Enter password for this .p12 certificate file if required."))
			}
			.alert(alertTitle, isPresented: $isStatusAlertPresenting) {
				Button(.localized("OK"), role: .cancel) {}
			} message: {
				Text(alertMessage)
			}
			.onAppear {
				_loadDirectoryContents()
			}
			.onChange(of: scenePhase) { phase in
				if phase == .active {
					_loadDirectoryContents()
				}
			}
		}
	}
	
	private var currentTitle: String {
		if currentDirectory.path == rootDirectory.path {
			return .localized("Files")
		} else {
			return currentDirectory.lastPathComponent
		}
	}
}

// MARK: - Views & Controls
extension FilesView {
	@ViewBuilder
	private func _scopeFilterBar() -> some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(FileScope.allCases, id: \.self) { scope in
					Button {
						withAnimation(.snappy(duration: 0.2)) {
							selectedScope = scope
						}
					} label: {
						HStack(spacing: 5) {
							Image(systemName: scope.systemIcon)
								.font(.system(size: 11, weight: .semibold))
							Text(scope.displayName)
								.font(.system(size: 13, weight: .medium))
						}
						.padding(.horizontal, 12)
						.padding(.vertical, 6)
						.background(selectedScope == scope ? Color.accentColor : Color(uiColor: .secondarySystemFill))
						.foregroundColor(selectedScope == scope ? .white : .primary)
						.clipShape(Capsule())
					}
					.buttonStyle(.plain)
				}
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
		}
	}
	
	@ViewBuilder
	private func _backFolderRow() -> some View {
		Button {
			_navigateBack()
		} label: {
			HStack(spacing: 12) {
				ZStack {
					RoundedRectangle(cornerRadius: 10, style: .continuous)
						.fill(Color.accentColor.opacity(0.15))
						.frame(width: 42, height: 42)
					
					Image(systemName: "folder.fill.badge.gearshape")
						.font(.system(size: 20, weight: .medium))
						.foregroundColor(.accentColor)
				}
				
				VStack(alignment: .leading, spacing: 3) {
					Text(directoryStack.last?.lastPathComponent ?? .localized("Documents"))
						.font(.system(size: 15, weight: .semibold))
						.foregroundColor(.primary)
					
					HStack(spacing: 4) {
						Image(systemName: "chevron.left")
							.font(.system(size: 10, weight: .bold))
						Text(.localized("Back to parent folder"))
							.font(.system(size: 12))
					}
					.foregroundColor(.secondary)
				}
				Spacer()
			}
		}
		.buttonStyle(.plain)
	}
	
	@ViewBuilder
	private func _toolbarMenu() -> some View {
		Menu {
			Button {
				isImportingPresenting = true
			} label: {
				Label(.localized("Import from Files"), systemImage: "square.and.arrow.down")
			}
			
			Button {
				isDownloadURLPresenting = true
			} label: {
				Label(.localized("Download from URL"), systemImage: "globe")
			}
			
			Button {
				newFolderName = ""
				isCreateFolderPresenting = true
			} label: {
				Label(.localized("New Folder"), systemImage: "folder.badge.plus")
			}
			
			Divider()
			
			Button {
				_loadDirectoryContents()
			} label: {
				Label(.localized("Refresh"), systemImage: "arrow.clockwise")
			}
		} label: {
			Image(systemName: "ellipsis.circle")
				.font(.system(size: 17, weight: .semibold))
		}
	}
	
	@ViewBuilder
	private func _emptyStateView() -> some View {
		if #available(iOS 17, *) {
			ContentUnavailableView {
				Label(.localized("No Files Found"), systemImage: "folder.badge.questionmark")
			} description: {
				Text(.localized("Save or drop files into NH-Signer via the iOS Files app (On My iPhone > NH-Signer), or tap below to import."))
			} actions: {
				Button {
					isImportingPresenting = true
				} label: {
					NBButton(.localized("Import Files"), style: .text)
				}
			}
		} else {
			VStack(spacing: 12) {
				Image(systemName: "folder.badge.questionmark")
					.font(.system(size: 48))
					.foregroundColor(.secondary)
				Text(.localized("No Files Found"))
					.font(.headline)
				Text(.localized("Save files into NH-Signer via Files app or tap Import."))
					.font(.subheadline)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 32)
				Button {
					isImportingPresenting = true
				} label: {
					Text(.localized("Import Files"))
						.fontWeight(.semibold)
						.padding(.horizontal, 20)
						.padding(.vertical, 8)
						.background(Color.accentColor)
						.foregroundColor(.white)
						.clipShape(Capsule())
				}
			}
			.padding()
		}
	}
	
	@ViewBuilder
	private func _storageFooter() -> some View {
		let totalSize = items.reduce(Int64(0)) { $0 + $1.size }
		let formattedTotal = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
		let freeSpace = _getFreeDiskSpace()
		
		HStack {
			Text("\(items.count) \(items.count == 1 ? "item" : "items") (\(formattedTotal))")
				.font(.system(size: 12, weight: .medium))
				.foregroundColor(.secondary)
			
			if let free = freeSpace {
				Spacer()
				Text("\(free) free")
					.font(.system(size: 12, weight: .medium))
					.foregroundColor(.secondary)
			}
		}
		.padding(.horizontal, 18)
		.padding(.vertical, 8)
		.background(Color(uiColor: .systemGroupedBackground))
	}
}

// MARK: - File Operations & Actions
extension FilesView {
	private func _loadDirectoryContents() {
		let fm = FileManager.default
		do {
			let urls = try fm.contentsOfDirectory(
				at: currentDirectory,
				includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
				options: [.skipsHiddenFiles]
			)
			
			var loadedItems: [FileItem] = []
			for url in urls {
				// Don't show system or cache files
				let name = url.lastPathComponent
				if name.hasPrefix(".") || name == "StoreKit" { continue }
				
				let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
				let isDir = resourceValues?.isDirectory ?? false
				let size = Int64(resourceValues?.fileSize ?? 0)
				let modDate = resourceValues?.contentModificationDate ?? Date()
				
				loadedItems.append(FileItem(
					url: url,
					isDirectory: isDir,
					size: size,
					modificationDate: modDate
				))
			}
			
			// Folders first, then alphabetically
			loadedItems.sort { a, b in
				if a.isDirectory != b.isDirectory {
					return a.isDirectory && !b.isDirectory
				}
				return a.name.localizedStandardCompare(b.name) == .orderedAscending
			}
			
			self.items = loadedItems
		} catch {
			print("[!] Error listing files in \(currentDirectory):", error)
		}
	}
	
	private func _handleItemSelect(_ item: FileItem) {
		if item.isDirectory {
			directoryStack.append(currentDirectory)
			currentDirectory = item.url
			_loadDirectoryContents()
		} else if item.isIPA {
			_importIPAToLibrary(item)
		} else if item.isCertificate {
			_promptImportCertificate(item)
		} else if item.isProvision {
			_importProvisionFile(item)
		} else if item.isArchive {
			_unzipArchive(item)
		} else {
			_shareFile(item)
		}
	}
	
	private func _navigateBack() {
		guard let previous = directoryStack.popLast() else { return }
		currentDirectory = previous
		_loadDirectoryContents()
	}
	
	// Import IPA directly into Library
	private func _importIPAToLibrary(_ item: FileItem) {
		let generator = UINotificationFeedbackGenerator()
		generator.prepare()
		
		let id = "FeatherManualDownload_\(UUID().uuidString)"
		let dl = DownloadManager.shared.startArchive(from: item.url, id: id)
		
		do {
			try DownloadManager.shared.handlePachageFile(url: item.url, dl: dl)
			generator.notificationOccurred(.success)
			_showStatus(title: .localized("Success"), message: .localized("App imported to Library successfully! You can now sign and install it."))
		} catch {
			generator.notificationOccurred(.error)
			_showStatus(title: .localized("Error"), message: error.localizedDescription)
		}
	}
	
	// Certificate import
	private func _promptImportCertificate(_ item: FileItem) {
		certToImport = item
		certPassword = ""
		isCertPasswordAlertPresenting = true
	}
	
	private func _performImportCertificate() {
		guard let cert = certToImport else { return }
		let generator = UINotificationFeedbackGenerator()
		generator.prepare()
		
		// Look for matching .mobileprovision file in current directory
		let fm = FileManager.default
		let baseName = cert.url.deletingPathExtension().lastPathComponent
		var provisionURL: URL? = nil
		
		for candidate in items where candidate.isProvision {
			if candidate.url.deletingPathExtension().lastPathComponent == baseName {
				provisionURL = candidate.url
				break
			}
		}
		
		if provisionURL == nil {
			provisionURL = items.first(where: { $0.isProvision })?.url
		}
		
		guard let validProvision = provisionURL else {
			_showStatus(title: .localized("Missing Provisioning Profile"), message: .localized("Please place a matching .mobileprovision file in the same folder as this .p12 certificate."))
			return
		}
		
		FR.handleCertificateFiles(
			p12URL: cert.url,
			provisionURL: validProvision,
			p12Password: certPassword,
			certificateName: baseName
		) { error in
			if let error = error {
				generator.notificationOccurred(.error)
				_showStatus(title: .localized("Import Error"), message: error.localizedDescription)
			} else {
				generator.notificationOccurred(.success)
				_showStatus(title: .localized("Success"), message: .localized("Certificate imported successfully!"))
			}
		}
	}
	
	// Provision file import
	private func _importProvisionFile(_ item: FileItem) {
		let dest = FileManager.default.certificates.appendingPathComponent(item.name)
		do {
			try FileManager.default.createDirectoryIfNeeded(at: FileManager.default.certificates)
			try FileManager.default.removeFileIfNeeded(at: dest)
			try FileManager.default.copyItem(at: item.url, to: dest)
			_showStatus(title: .localized("Success"), message: .localized("Provisioning file saved to Certificates."))
		} catch {
			_showStatus(title: .localized("Error"), message: error.localizedDescription)
		}
	}
	
	// Unzip archive
	private func _unzipArchive(_ item: FileItem) {
		let generator = UINotificationFeedbackGenerator()
		generator.prepare()
		
		let folderName = item.url.deletingPathExtension().lastPathComponent
		let dest = currentDirectory.appendingPathComponent(folderName, isDirectory: true)
		
		do {
			try FileManager.default.createDirectoryIfNeeded(at: dest)
			try Zip.unzipFile(item.url, destination: dest, overwrite: true, password: nil)
			generator.notificationOccurred(.success)
			_loadDirectoryContents()
			_showStatus(title: .localized("Success"), message: .localized("Archive extracted to folder '\(folderName)'."))
		} catch {
			generator.notificationOccurred(.error)
			_showStatus(title: .localized("Error"), message: error.localizedDescription)
		}
	}
	
	// Document picker import
	private func _handleDocumentsPicked(_ urls: [URL]) {
		guard !urls.isEmpty else { return }
		let fm = FileManager.default
		
		for sourceURL in urls {
			let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
			defer {
				if isSecurityScoped {
					sourceURL.stopAccessingSecurityScopedResource()
				}
			}
			
			let destURL = currentDirectory.appendingPathComponent(sourceURL.lastPathComponent)
			do {
				try fm.removeFileIfNeeded(at: destURL)
				try fm.copyItem(at: sourceURL, to: destURL)
			} catch {
				print("[!] Failed copying \(sourceURL) to \(destURL):", error)
			}
		}
		_loadDirectoryContents()
	}
	
	// Download from URL
	private func _downloadFromURL() {
		guard let url = URL(string: downloadURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
		downloadURLString = ""
		_ = DownloadManager.shared.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
		_showStatus(title: .localized("Download Started"), message: .localized("File is downloading in the background. Check Download bar at the top."))
	}
	
	// New folder
	private func _createNewFolder() {
		let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		newFolderName = ""
		
		let folderURL = currentDirectory.appendingPathComponent(trimmed, isDirectory: true)
		do {
			try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
			_loadDirectoryContents()
		} catch {
			_showStatus(title: .localized("Error"), message: error.localizedDescription)
		}
	}
	
	// Rename
	private func _promptRename(_ item: FileItem) {
		fileToRename = item
		newFileName = item.name
		isRenameAlertPresenting = true
	}
	
	private func _performRename() {
		guard let file = fileToRename else { return }
		let trimmed = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty, trimmed != file.name else { return }
		
		let newURL = currentDirectory.appendingPathComponent(trimmed)
		do {
			try FileManager.default.moveItem(at: file.url, to: newURL)
			fileToRename = nil
			newFileName = ""
			_loadDirectoryContents()
		} catch {
			_showStatus(title: .localized("Error"), message: error.localizedDescription)
		}
	}
	
	// Delete
	private func _promptDelete(_ item: FileItem) {
		fileToDelete = item
		isDeleteAlertPresenting = true
	}
	
	private func _performDelete() {
		guard let file = fileToDelete else { return }
		do {
			try FileManager.default.removeItem(at: file.url)
			fileToDelete = nil
			_loadDirectoryContents()
		} catch {
			_showStatus(title: .localized("Error"), message: error.localizedDescription)
		}
	}
	
	// Share
	private func _shareFile(_ item: FileItem) {
		UIActivityViewController.show(activityItems: [item.url])
	}
	
	private func _showStatus(title: String, message: String) {
		alertTitle = title
		alertMessage = message
		isStatusAlertPresenting = true
	}
	
	private func _getFreeDiskSpace() -> String? {
		guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return nil }
		do {
			let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
			if let free = attrs[.systemFreeSize] as? Int64 {
				return ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
			}
		} catch {}
		return nil
	}
}

// MARK: - Scope Enum
enum FileScope: String, CaseIterable, Hashable {
	case all
	case ipas
	case certificates
	case archives
	case folders
	
	var displayName: String {
		switch self {
		case .all: return .localized("All")
		case .ipas: return "IPAs"
		case .certificates: return .localized("Certs")
		case .archives: return .localized("Archives")
		case .folders: return .localized("Folders")
		}
	}
	
	var systemIcon: String {
		switch self {
		case .all: return "tray.2.fill"
		case .ipas: return "app.badge.checkmark"
		case .certificates: return "lock.rectangle.on.rectangle.fill"
		case .archives: return "doc.zipper"
		case .folders: return "folder.fill"
		}
	}
}
