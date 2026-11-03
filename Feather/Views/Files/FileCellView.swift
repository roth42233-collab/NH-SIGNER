//
//  FileCellView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleViews

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
				// Icon
				ZStack {
					RoundedRectangle(cornerRadius: 10, style: .continuous)
						.fill(item.iconColor.opacity(0.15))
						.frame(width: 42, height: 42)
					
					Image(systemName: item.systemIcon)
						.font(.system(size: 20, weight: .semibold))
						.foregroundColor(item.iconColor)
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

