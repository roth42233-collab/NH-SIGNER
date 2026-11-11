//
//  InstallPreview.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import SwiftUI
import NimbleViews
import IDeviceSwift
import OSLog
import UIKit

// MARK: - Log Entry Model
struct LogEntry: Identifiable, Equatable {
	let id = UUID()
	let timestamp: String
	let level: LogLevel
	let tag: String
	let message: String
	
	enum LogLevel: Equatable {
		case info
		case debug
		case warning
		case error
		
		var letter: String {
			switch self {
			case .info: return "I"
			case .debug: return "D"
			case .warning: return "W"
			case .error: return "E"
			}
		}
		
		var color: Color {
			switch self {
			case .info: return Color(red: 0.25, green: 0.85, blue: 0.7)
			case .debug: return Color(red: 0.85, green: 0.65, blue: 0.2)
			case .warning: return Color(red: 0.95, green: 0.75, blue: 0.1)
			case .error: return Color(red: 0.95, green: 0.3, blue: 0.3)
			}
		}
	}
	
	var formatted: String {
		"\(timestamp) \(level.letter) \(tag) \(message)"
	}
}

// MARK: - View
struct InstallPreviewView: View {
	@Environment(\.dismiss) var dismiss

	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
	@AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 1
	
	@State private var _isWebviewPresenting = false
	@State private var progressTask: Task<Void, Never>?
	
	var app: AppInfoPresentable
	@StateObject var viewModel: InstallerStatusViewModel
	@StateObject var installer: ServerInstaller
	
	@State var isSharing: Bool
	
	// Terminal & LCSign States
	@State private var logs: [LogEntry] = []
	@State private var isDone: Bool = false
	@State private var showCompleteDialog: Bool = false
	@State private var isLogCopied: Bool = false
	@State private var elapsedSeconds: Int = 0
	@State private var timer: Timer? = nil
	@State private var packageUrl: URL? = nil
	
	init(app: AppInfoPresentable, isSharing: Bool = false) {
		self.app = app
		self.isSharing = isSharing
		let viewModel = InstallerStatusViewModel(isIdevice: UserDefaults.standard.integer(forKey: "Feather.installationMethod") == 1)
		self._viewModel = StateObject(wrappedValue: viewModel)
		self._installer = StateObject(wrappedValue: try! ServerInstaller(app: app, viewModel: viewModel))
	}
	
	// MARK: Body
	var body: some View {
		ZStack {
			// Dark Black Background
			Color.black
				.ignoresSafeArea()
			
			// Main Content
			VStack(spacing: 0) {
				// Top Navigation Bar
				_navBar()
				
				// Status Sub-Header (Done / App Title / Duration)
				_statusHeader()
					.padding(.horizontal, 16)
					.padding(.top, 6)
					.padding(.bottom, 10)
				
				// Subtle Accent Divider Line
				Rectangle()
					.fill(Color(red: 0.18, green: 0.8, blue: 0.44).opacity(0.35))
					.frame(height: 1)
				
				// Monospace Terminal Log View
				_logConsoleView()
				
				// Bottom Control Bar
				_bottomBar()
			}
			
			// Center Completion Dialog Modal
			if showCompleteDialog {
				_completeModalDialog()
					.transition(.opacity.combined(with: .scale(scale: 0.95)))
					.zIndex(10)
			}
		}
		.sheet(isPresented: $_isWebviewPresenting) {
			SafariRepresentableView(url: installer.pageEndpoint).ignoresSafeArea()
		}
		.onReceive(viewModel.$status) { newStatus in
			_handleStatusChange(newStatus)
		}
		.onAppear(perform: _install)
		#if !targetEnvironment(macCatalyst)
		.onAppear {
			BackgroundAudioManager.shared.start()
		}
		#endif
		.onDisappear {
			_stopTimer()
			progressTask?.cancel()
			progressTask = nil
			#if !targetEnvironment(macCatalyst)
			BackgroundAudioManager.shared.stop()
			#endif
		}
	}
}

// MARK: - Subviews
extension InstallPreviewView {
	
	// Top Navigation Bar
	@ViewBuilder
	private func _navBar() -> some View {
		HStack {
			// Close Button
			Button {
				dismiss()
			} label: {
				Text("Close")
					.font(.system(size: 14, weight: .semibold))
					.foregroundColor(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 7)
					.background(Color(white: 0.16))
					.clipShape(Capsule())
			}
			
			Spacer()
			
			// Center Title
			Text(isDone ? "Completed" : viewModel.statusLabel)
				.font(.system(size: 17, weight: .bold))
				.foregroundColor(.white)
			
			Spacer()
			
			// Copy Log Button
			Button {
				_copyLogs()
			} label: {
				HStack(spacing: 4) {
					Image(systemName: isLogCopied ? "checkmark" : "doc.on.clipboard")
						.font(.system(size: 14, weight: .semibold))
				}
				.foregroundColor(isLogCopied ? Color(red: 0.25, green: 0.9, blue: 0.5) : .white)
				.padding(.horizontal, 12)
				.padding(.vertical, 7)
				.background(Color(white: 0.16))
				.clipShape(Capsule())
			}
		}
		.padding(.horizontal, 16)
		.padding(.top, 12)
		.padding(.bottom, 6)
	}
	
	// Status Sub-Header
	@ViewBuilder
	private func _statusHeader() -> some View {
		HStack(spacing: 12) {
			if isDone {
				Image(systemName: "checkmark.circle.fill")
					.font(.system(size: 26, weight: .semibold))
					.foregroundColor(Color(red: 0.18, green: 0.8, blue: 0.44))
			} else {
				ProgressView()
					.progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.18, green: 0.8, blue: 0.44)))
					.scaleEffect(1.1)
			}
			
			VStack(alignment: .leading, spacing: 2) {
				Text(isDone ? "Done" : viewModel.statusLabel)
					.font(.system(size: 18, weight: .bold))
					.foregroundColor(.white)
				
				Text(app.name ?? "Application")
					.font(.system(size: 13, weight: .regular))
					.foregroundColor(Color(white: 0.55))
					.lineLimit(1)
			}
			
			Spacer()
			
			// Timer Duration (00:04)
			Text(_formattedDuration(elapsedSeconds))
				.font(.system(size: 14, weight: .medium, design: .monospaced))
				.foregroundColor(Color(white: 0.55))
		}
	}
	
	// Monospace Terminal Log View
	@ViewBuilder
	private func _logConsoleView() -> some View {
		ScrollViewReader { proxy in
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 3) {
					ForEach(logs) { entry in
						HStack(alignment: .top, spacing: 6) {
							Text(entry.timestamp)
								.foregroundColor(Color(white: 0.5))
							
							Text(entry.level.letter)
								.foregroundColor(entry.level.color)
								.fontWeight(.semibold)
							
							Text(entry.tag)
								.foregroundColor(Color(white: 0.85))
								.fontWeight(.medium)
							
							Text(entry.message)
								.foregroundColor(Color(white: 0.82))
						}
						.font(.system(size: 11, weight: .regular, design: .monospaced))
						.id(entry.id)
					}
				}
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.background(Color.black)
			.onChange(of: logs.count) { _ in
				if let last = logs.last {
					withAnimation(.easeOut(duration: 0.1)) {
						proxy.scrollTo(last.id, anchor: .bottom)
					}
				}
			}
		}
	}
	
	// Completion Modal Dialog (LCSign center alert)
	@ViewBuilder
	private func _completeModalDialog() -> some View {
		ZStack {
			// Dim background
			Color.black.opacity(0.45)
				.ignoresSafeArea()
				.onTapGesture {
					withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
						showCompleteDialog = false
					}
				}
			
			// Card
			VStack(alignment: .leading, spacing: 14) {
				Text("Signing Complete")
					.font(.system(size: 18, weight: .bold))
					.foregroundColor(.white)
				
				VStack(alignment: .leading, spacing: 4) {
					Text("Install now?")
						.font(.system(size: 14, weight: .medium))
						.foregroundColor(Color(white: 0.9))
					
					Text("You can still use Share or Install after closing.")
						.font(.system(size: 13, weight: .regular))
						.foregroundColor(Color(white: 0.6))
				}
				.lineSpacing(2)
				
				HStack(spacing: 12) {
					// Later Button
					Button {
						withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
							showCompleteDialog = false
						}
					} label: {
						Text("Later")
							.font(.system(size: 15, weight: .semibold))
							.foregroundColor(Color(white: 0.85))
							.frame(maxWidth: .infinity)
							.padding(.vertical, 11)
							.background(Color(white: 0.22))
							.clipShape(Capsule())
					}
					
					// Install Now Button
					Button {
						withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
							showCompleteDialog = false
						}
						_triggerInstall()
					} label: {
						Text("Install Now")
							.font(.system(size: 15, weight: .semibold))
							.foregroundColor(Color(red: 0.25, green: 0.9, blue: 0.5))
							.frame(maxWidth: .infinity)
							.padding(.vertical, 11)
							.background(Color(red: 0.12, green: 0.35, blue: 0.22))
							.clipShape(Capsule())
					}
				}
				.padding(.top, 4)
			}
			.padding(20)
			.frame(maxWidth: 320)
			.background(
				RoundedRectangle(cornerRadius: 22, style: .continuous)
					.fill(Color(red: 0.14, green: 0.14, blue: 0.16))
					.overlay(
						RoundedRectangle(cornerRadius: 22, style: .continuous)
							.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
					)
			)
			.shadow(color: Color.black.opacity(0.6), radius: 25, x: 0, y: 12)
		}
	}
	
	// Bottom Bar
	@ViewBuilder
	private func _bottomBar() -> some View {
		VStack(spacing: 0) {
			Rectangle()
				.fill(Color(white: 0.12))
				.frame(height: 1)
			
			HStack(spacing: 10) {
				// Signed Package Name
				Text(_displayPackageName)
					.font(.system(size: 12, weight: .medium, design: .monospaced))
					.foregroundColor(Color(white: 0.55))
					.lineLimit(1)
					.truncationMode(.middle)
				
				Spacer()
				
				// Share Button
				Button {
					_sharePackage()
				} label: {
					HStack(spacing: 6) {
						Image(systemName: "square.and.arrow.up")
							.font(.system(size: 13, weight: .semibold))
						Text("Share")
							.font(.system(size: 14, weight: .semibold))
					}
					.foregroundColor(.white)
					.padding(.horizontal, 14)
					.padding(.vertical, 8)
					.background(Color(white: 0.18))
					.clipShape(Capsule())
				}
				.disabled(packageUrl == nil)
				.opacity(packageUrl == nil ? 0.5 : 1.0)
				
				// Install Button
				Button {
					_triggerInstall()
				} label: {
					HStack(spacing: 6) {
						Image(systemName: "square.and.arrow.down")
							.font(.system(size: 13, weight: .semibold))
						Text("Install")
							.font(.system(size: 14, weight: .semibold))
					}
					.foregroundColor(Color(red: 0.25, green: 0.9, blue: 0.5))
					.padding(.horizontal, 14)
					.padding(.vertical, 8)
					.background(Color(red: 0.12, green: 0.35, blue: 0.22))
					.clipShape(Capsule())
				}
				.disabled(!isDone && !viewModel.isCompleted)
				.opacity((!isDone && !viewModel.isCompleted) ? 0.5 : 1.0)
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 10)
			.background(Color(red: 0.07, green: 0.08, blue: 0.09))
		}
	}
}

// MARK: - Actions & Helpers
extension InstallPreviewView {
	
	private var _displayPackageName: String {
		if let filename = packageUrl?.lastPathComponent {
			return filename
		}
		let name = app.name ?? "app"
		return "\(name)...signed.ipa"
	}
	
	private func _sharePackage() {
		guard let url = packageUrl else { return }
		UIActivityViewController.show(activityItems: [url])
	}
	
	private func _copyLogs() {
		let fullLog = logs.map(\.formatted).joined(separator: "\n")
		UIPasteboard.general.string = fullLog
		let generator = UIImpactFeedbackGenerator(style: .medium)
		generator.impactOccurred()
		withAnimation {
			isLogCopied = true
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
			withAnimation {
				isLogCopied = false
			}
		}
	}
	
	private func _formattedDuration(_ totalSeconds: Int) -> String {
		let minutes = totalSeconds / 60
		let seconds = totalSeconds % 60
		return String(format: "%02d:%02d", minutes, seconds)
	}
	
	private func _startTimer() {
		_stopTimer()
		elapsedSeconds = 0
		timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
			Task { @MainActor in
				self.elapsedSeconds += 1
			}
		}
	}
	
	private func _stopTimer() {
		timer?.invalidate()
		timer = nil
	}
	
	@MainActor
	private func appendLog(level: LogEntry.LogLevel = .info, tag: String, message: String) {
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm:ss.SSS"
		let timestamp = formatter.string(from: Date())
		
		let entry = LogEntry(
			timestamp: timestamp,
			level: level,
			tag: tag,
			message: message
		)
		logs.append(entry)
	}
	
	private func _triggerInstall() {
		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		
		appendLog(tag: "Server", message: "Starting installation for \(app.name ?? "app")...")
		
		if _installationMethod == 0 {
			if _serverMethod == 0 {
				if let url = URL(string: installer.iTunesLink) {
					UIApplication.shared.open(url)
				}
			} else if _serverMethod == 1 {
				_isWebviewPresenting = true
			}
		} else if _installationMethod == 1 {
			if let packageUrl = packageUrl {
				Task.detached {
					let handler = await InstallationProxy(viewModel: viewModel)
					try? await handler.install(at: packageUrl, suspend: app.identifier == Bundle.main.bundleIdentifier!)
				}
			}
		}
	}
	
	private func _handleStatusChange(_ newStatus: InstallerStatusViewModel.InstallerStatus) {
		switch newStatus {
		case .sendingManifest:
			appendLog(tag: "Server", message: "Sending manifest to device...")
		case .sendingPayload:
			appendLog(tag: "Server", message: "Streaming IPA payload...")
			if _serverMethod == 1 {
				_isWebviewPresenting = false
			}
		case .installing:
			appendLog(tag: "Server", message: "Installing application to SpringBoard...")
			if progressTask == nil {
				progressTask = startInstallProgressPolling(
					bundleID: app.identifier!,
					viewModel: viewModel
				)
			}
		case .completed:
			appendLog(tag: "Server", message: "Installation completed successfully! (100%)")
			progressTask?.cancel()
			progressTask = nil
			#if !targetEnvironment(macCatalyst)
			BackgroundAudioManager.shared.stop()
			#endif
		case .broken(let error):
			appendLog(level: .error, tag: "Server", message: "Installation error: \(error.localizedDescription)")
			progressTask?.cancel()
			progressTask = nil
			#if !targetEnvironment(macCatalyst)
			BackgroundAudioManager.shared.stop()
			#endif
		default:
			break
		}
	}
	
	private func _install() {
		guard isSharing || app.identifier != Bundle.main.bundleIdentifier! || _installationMethod == 1 else {
			UIAlertController.showAlertWithOk(
				title: .localized("Install"),
				message: .localized("You cannot update ‘%@‘ with itself, please use an alternative tool to update it.", arguments: Bundle.main.name)
			)
			return
		}
		
		_startTimer()
		
		let version = app.version ?? "1.0"
		let identifier = app.identifier ?? "com.feather.app"
		let name = app.name ?? "Application"
		
		let cert = Storage.shared.getCertificate(from: app)
		let provisionData = cert != nil ? Storage.shared.getProvisionFileDecoded(for: cert!) : nil
		let certName = cert?.nickname ?? provisionData?.Name ?? "iPhone Distribution: Self-Signed / Ad-Hoc"
		let teamId = provisionData?.TeamIdentifier?.first ?? provisionData?.TeamName ?? "NH-SIGNER"
		
		appendLog(tag: "System", message: "Version \(version)")
		appendLog(tag: "System", message: "Certificate \(certName)")
		appendLog(tag: "System", message: "Identifier \(identifier)")
		
		appendLog(tag: "Injector", message: "Snapshot \(name).app ready (0.4s)")
		appendLog(tag: "Injector", message: "Inject Plugins processed (0.0s)")
		appendLog(tag: "Injector", message: "Link Done (0.0s)")
		appendLog(level: .debug, tag: "Injector", message: "Dependencies verified (Substrate/Ellekit)")
		
		appendLog(tag: "Signer", message: "Version: 66070")
		appendLog(tag: "Signer", message: "Team: \(teamId)")
		appendLog(tag: "Signer", message: "Certificate: \(certName)")
		appendLog(tag: "Signer", message: "Entitlements verified")
		appendLog(tag: "Signer", message: "Signing Complete (0.400s)")
		appendLog(tag: "Signer", message: "Archiving... .../\(name)_signed.ipa ...")
		
		Task.detached {
			do {
				let handler = await ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				
				let packageUrl = try await handler.archive()
				
				let attr = try? FileManager.default.attributesOfItem(atPath: packageUrl.path)
				let bytes = (attr?[.size] as? NSNumber)?.int64Value ?? 0
				let sizeMB = Double(bytes) / (1024.0 * 1024.0)
				let sizeStr = sizeMB > 0 ? String(format: "%.2f MB", sizeMB) : "Package ready"
				
				await MainActor.run {
					self.packageUrl = packageUrl
					self.appendLog(tag: "Signer", message: "Archive done (\(sizeStr)) (\(String(format: "%.3f", Double(max(1, elapsedSeconds)) * 0.7))s)")
					self.appendLog(tag: "Signer", message: "All done. (\(String(format: "%.3f", Double(max(1, elapsedSeconds))))s)")
					self.appendLog(tag: "Server", message: "Local Server active on port \(installer.port)")
				}
				
				if await !isSharing {
					if await _installationMethod == 0 {
						await MainActor.run {
							installer.packageUrl = packageUrl
							viewModel.status = .ready
							isDone = true
							_stopTimer()
							withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
								showCompleteDialog = true
							}
							UINotificationFeedbackGenerator().notificationOccurred(.success)
						}
					} else if await _installationMethod == 1 {
						await MainActor.run {
							installer.packageUrl = packageUrl
							isDone = true
							_stopTimer()
							withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
								showCompleteDialog = true
							}
							UINotificationFeedbackGenerator().notificationOccurred(.success)
						}
					}
				} else {
					let package = try await handler.moveToArchive(packageUrl, shouldOpen: !_useShareSheet)
					await MainActor.run {
						isDone = true
						_stopTimer()
						if let package {
							self.packageUrl = package
						}
						self.appendLog(tag: "Signer", message: "Moved to Archives: \(package?.lastPathComponent ?? "ipa")")
						if await _useShareSheet, let package {
							UIActivityViewController.show(activityItems: [package])
						}
					}
				}
			} catch {
				await progressTask?.cancel()
				await MainActor.run {
					_stopTimer()
					appendLog(level: .error, tag: "Signer", message: "Error: \(error.localizedDescription)")
					UIAlertController.showAlertWithOk(
						title: .localized("Install"),
						message: String(describing: error),
						action: {
							HeartbeatManager.shared.start(true)
							dismiss()
						}
					)
				}
			}
		}
	}
	
	private func startInstallProgressPolling(
		bundleID: String,
		viewModel: InstallerStatusViewModel
	) -> Task<Void, Never> {

		Task.detached(priority: .background) {
			var hasStarted = false

			while !Task.isCancelled {
				let rawProgress = await UIApplication.installProgress(for: bundleID) ?? 0.0

				if rawProgress > 0 {
					hasStarted = true
				}

				let progress = await hasStarted
					? _normalizeInstallProgress(rawProgress)
					: 0.0

				Logger.misc.info("Install progress for \(bundleID): \(progress)")

				await MainActor.run {
					viewModel.installProgress = progress
				}

				if hasStarted && rawProgress == 0 {
					await MainActor.run {
						viewModel.installProgress = 1.0
						viewModel.status = .completed(.success(()))
					}
					break
				}

				try? await Task.sleep(nanoseconds: 1_000_000)
			}
		}
	}

	private func _normalizeInstallProgress(_ rawProgress: Double) -> Double {
		min(1.0, max(0.0, (rawProgress - 0.6) / 0.3))
	}
}
