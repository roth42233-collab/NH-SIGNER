//
//  FileCellView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import ImageIO

struct FileCellView: View {
	let item: FileItem
	var onSelect: (FileItem) -> Void
	var onImportToLibrary: (FileItem) -> Void
	var onImportCertificate: (FileItem) -> Void
	var onImportProvision: (FileItem) -> Void
	var onUnzip: (FileItem) -> Void
	var onRename: (FileItem) -> Void
	var onDelete: (FileItem) -> Void
	var onShare: (FileItem) -> Void

	var body: some View {
		Button {
			onSelect(item)
		} label: {
			HStack(spacing: 12) {
				// Icon (Real App Icon for IPAs, thumbnail for images, or system icon)
				if item.isIPA {
					FileIPAIconView(url: item.url, systemIcon: item.systemIcon, iconColor: item.iconColor)
				} else if item.isImage {
					FileImageThumbnailView(url: item.url, systemIcon: item.systemIcon, iconColor: item.iconColor)
				} else {
					ZStack {
						RoundedRectangle(cornerRadius: 10, style: .continuous)
							.fill(item.iconColor.opacity(0.15))
							.frame(width: 42, height: 42)
						
						Image(systemName: item.systemIcon)
							.font(.system(size: 20, weight: .semibold))
							.foregroundColor(item.iconColor)
					}
				}
				
				// File Details
				VStack(alignment: .leading, spacing: 3) {
					Text(item.name)
						.font(.system(size: 16, weight: .medium))
						.foregroundColor(.primary)
						.lineLimit(1)
						.truncationMode(.middle)
					
					HStack(spacing: 6) {
						Text(item.formattedDate)
							.font(.system(size: 13))
							.foregroundColor(.secondary)
						
						if !item.isDirectory && !item.formattedSize.isEmpty {
							Text("•")
								.font(.system(size: 11))
								.foregroundColor(.secondary)
							
							Text(item.formattedSize)
								.font(.system(size: 13))
								.foregroundColor(.secondary)
						}
					}
				}
				
				Spacer()
				
				// Badge or Folder chevron
				if item.isDirectory {
					Image(systemName: "chevron.right")
						.font(.system(size: 13, weight: .semibold))
						.foregroundColor(Color(uiColor: .tertiaryLabel))
				} else if let badge = item.badgeText {
					Text(badge)
						.font(.system(size: 11, weight: .bold))
						.padding(.horizontal, 7)
						.padding(.vertical, 3)
						.background(item.iconColor.opacity(0.18))
						.foregroundColor(item.iconColor)
						.clipShape(Capsule())
				}
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.contextMenu {
			_contextMenuActions()
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			Button(role: .destructive) {
				onDelete(item)
			} label: {
				Label(.localized("Delete"), systemImage: "trash")
			}
		}
		.swipeActions(edge: .leading) {
			if item.isIPA {
				Button {
					onImportToLibrary(item)
				} label: {
					Label(.localized("Sign"), systemImage: "signature")
				}
				.tint(.blue)
			} else {
				Button {
					onShare(item)
				} label: {
					Label(.localized("Share"), systemImage: "square.and.arrow.up")
				}
				.tint(.accentColor)
			}
		}
	}
	
	@ViewBuilder
	private func _contextMenuActions() -> some View {
		if item.isIPA {
			Button {
				onImportToLibrary(item)
			} label: {
				Label(.localized("Import to Library & Sign"), systemImage: "signature")
			}
		}
		
		if item.isCertificate {
			Button {
				onImportCertificate(item)
			} label: {
				Label(.localized("Import Certificate"), systemImage: "lock.rectangle.on.rectangle")
			}
		}
		
		if item.isProvision {
			Button {
				onImportProvision(item)
			} label: {
				Label(.localized("Import Provisioning File"), systemImage: "person.badge.shield.checkmark")
			}
		}
		
		if item.isArchive {
			Button {
				onUnzip(item)
			} label: {
				Label(.localized("Unzip Archive"), systemImage: "doc.zipper")
			}
		}
		
		if !item.isDirectory {
			Button {
				onShare(item)
			} label: {
				Label(.localized("Share"), systemImage: "square.and.arrow.up")
			}
		}
		
		Button {
			onRename(item)
		} label: {
			Label(.localized("Rename"), systemImage: "pencil")
		}
		
		Divider()
		
		Button(role: .destructive) {
			onDelete(item)
		} label: {
			Label(.localized("Delete"), systemImage: "trash")
		}
	}
}

// MARK: - IPA App Icon View with Caching
struct FileIPAIconView: View {
	let url: URL
	let systemIcon: String
	let iconColor: Color
	
	@State private var icon: UIImage? = nil
	
	var body: some View {
		Group {
			if let icon = icon {
				Image(uiImage: icon)
					.appIconStyle(size: 42)
			} else {
				ZStack {
					RoundedRectangle(cornerRadius: 10, style: .continuous)
						.fill(iconColor.opacity(0.15))
						.frame(width: 42, height: 42)
					
					Image(systemName: systemIcon)
						.font(.system(size: 20, weight: .semibold))
						.foregroundColor(iconColor)
				}
			}
		}
		.task(id: url) {
			if let cached = IPAIconExtractor.shared.cachedImage(for: url) {
				self.icon = cached
				return
			}
			if let extracted = await IPAIconExtractor.shared.extractIcon(from: url) {
				self.icon = extracted
			}
		}
	}
}

// MARK: - Image Thumbnail Cache & View
final class ImageThumbnailCache: @unchecked Sendable {
	static let shared = ImageThumbnailCache()
	private let memoryCache = NSCache<NSURL, UIImage>()
	
	init() {
		memoryCache.countLimit = 300
		memoryCache.totalCostLimit = 60 * 1024 * 1024 // 60 MB
	}
	
	func thumbnail(for url: URL) -> UIImage? {
		return memoryCache.object(forKey: url as NSURL)
	}
	
	func loadThumbnail(for url: URL, targetSize: CGSize = CGSize(width: 84, height: 84)) async -> UIImage? {
		if let mem = memoryCache.object(forKey: url as NSURL) {
			return mem
		}
		
		return await Task.detached(priority: .userInitiated) { [weak self] () -> UIImage? in
			guard let self = self else { return nil }
			
			// Downsample using ImageIO directly from disk to keep memory low
			if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
				let maxPixel = max(targetSize.width, targetSize.height) * 2
				let options: [CFString: Any] = [
					kCGImageSourceCreateThumbnailFromImageAlways: true,
					kCGImageSourceShouldCacheImmediately: true,
					kCGImageSourceCreateThumbnailWithTransform: true,
					kCGImageSourceThumbnailMaxPixelSize: maxPixel
				]
				if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
					let thumb = UIImage(cgImage: cgImage)
					self.memoryCache.setObject(thumb, forKey: url as NSURL)
					return thumb
				}
			}
			
			// Fallback to UIImage(contentsOfFile:) for Apple CgBI-compressed PNGs
			if let img = UIImage(contentsOfFile: url.path) {
				self.memoryCache.setObject(img, forKey: url as NSURL)
				return img
			}
			return nil
		}.value
	}
}

struct FileImageThumbnailView: View {
	let url: URL
	let systemIcon: String
	let iconColor: Color
	
	@State private var thumbnail: UIImage? = nil
	
	var body: some View {
		Group {
			if let thumbnail = thumbnail {
				Image(uiImage: thumbnail)
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(width: 42, height: 42)
					.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
					.overlay(
						RoundedRectangle(cornerRadius: 10, style: .continuous)
							.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
					)
			} else {
				ZStack {
					RoundedRectangle(cornerRadius: 10, style: .continuous)
						.fill(iconColor.opacity(0.15))
						.frame(width: 42, height: 42)
					
					Image(systemName: systemIcon)
						.font(.system(size: 20, weight: .semibold))
						.foregroundColor(iconColor)
				}
			}
		}
		.task(id: url) {
			if let cached = ImageThumbnailCache.shared.thumbnail(for: url) {
				self.thumbnail = cached
				return
			}
			if let loaded = await ImageThumbnailCache.shared.loadThumbnail(for: url) {
				self.thumbnail = loaded
			}
		}
	}
}
