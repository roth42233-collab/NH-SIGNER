//
//  FileItem.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import Foundation

struct FileItem: Identifiable, Hashable {
	let url: URL
	let isDirectory: Bool
	let size: Int64
	let modificationDate: Date
	
	var id: String {
		url.path
	}
	
	var name: String {
		url.lastPathComponent
	}
	
	var pathExtension: String {
		url.pathExtension.lowercased()
	}
	
	var isIPA: Bool {
		pathExtension == "ipa" || pathExtension == "tipa"
	}
	
	var isCertificate: Bool {
		pathExtension == "p12"
	}
	
	var isProvision: Bool {
		pathExtension == "mobileprovision"
	}
	
	var isTweak: Bool {
		pathExtension == "dylib" || pathExtension == "deb"
	}
	
	var isArchive: Bool {
		pathExtension == "zip" || pathExtension == "tar" || pathExtension == "gz" || pathExtension == "7z"
	}
	
	var isImage: Bool {
		["png", "jpg", "jpeg", "webp", "gif", "heic"].contains(pathExtension)
	}
	
	var isText: Bool {
		["txt", "json", "plist", "log", "xml", "md", "sh"].contains(pathExtension)
	}
	
	var systemIcon: String {
		if isDirectory {
			return "folder.fill"
		}
		if isIPA {
			return "app.badge.checkmark"
		}
		if isCertificate {
			return "lock.rectangle.on.rectangle.fill"
		}
		if isProvision {
			return "person.badge.shield.checkmark.fill"
		}
		if isTweak {
			return "puzzlepiece.extension.fill"
		}
		if isArchive {
			return "doc.zipper"
		}
		if isImage {
			return "photo.fill"
		}
		if isText {
			return "doc.text.fill"
		}
		return "doc.fill"
	}
	
	var iconColor: Color {
		if isDirectory {
			return .accentColor
		}
		if isIPA {
			return .blue
		}
		if isCertificate {
			return .purple
		}
		if isProvision {
			return .green
		}
		if isTweak {
			return .orange
		}
		if isArchive {
			return .yellow
		}
		if isImage {
			return .cyan
		}
		return .secondary
	}
	
	var badgeText: String? {
		if isDirectory {
			return nil
		}
		if !pathExtension.isEmpty {
			return pathExtension.uppercased()
		}
		return nil
	}
	
	var formattedSize: String {
		if isDirectory {
			return ""
		}
		return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
	}
	
	var formattedDate: String {
		let formatter = DateFormatter()
		if Calendar.current.isDateInToday(modificationDate) {
			formatter.timeStyle = .short
			formatter.dateStyle = .none
			return "Today " + formatter.string(from: modificationDate)
		} else if Calendar.current.isDateInYesterday(modificationDate) {
			formatter.timeStyle = .short
			formatter.dateStyle = .none
			return "Yesterday " + formatter.string(from: modificationDate)
		} else {
			formatter.dateStyle = .short
			formatter.timeStyle = .short
			return formatter.string(from: modificationDate)
		}
	}
}

