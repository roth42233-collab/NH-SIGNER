//
//  AboutView.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import SwiftUI
import NimbleViews
import NimbleJSON

// MARK: - Extension: Model
extension AboutView {
	struct CreditsModel: Hashable {
		let name: String
		let desc: String
		let url: String
		let icon: String
	}
}

// MARK: - View
struct AboutView: View {
	@State private var _credits: [CreditsModel] = [
		.init(name: "NH-Signer Group", desc: "Telegram Community", url: "https://t.me/+6CL4Jef4xx8wNGZl", icon: "paperplane.fill"),
		.init(name: "SPP NH Tools", desc: "Telegram Channel", url: "https://t.me/sppnhtools", icon: "paperplane.fill"),
	]
	
	// MARK: Body
	var body: some View {
		NBList(.localized("About")) {
			Section {
				VStack {
					FRAppIconView(size: 72)
					
					Text(Bundle.main.name.isEmpty ? "NH-Signer" : Bundle.main.name)
						.font(.largeTitle)
						.bold()
						.foregroundStyle(Color.accentColor)
					
					HStack(spacing: 4) {
						Text(.localized("Version"))
						Text(Bundle.main.version)
					}
					.font(.footnote)
					.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity)
			.listRowBackground(EmptyView())
			
			NBSection(.localized("Credits")) {
				ForEach(_credits, id: \.url) { credit in
					_credit(name: credit.name, desc: credit.desc, url: credit.url, icon: credit.icon)
				}
				.transition(.slide)
			}
		}
	}
}

// MARK: - Extension: view
extension AboutView {
	@ViewBuilder
	private func _credit(
		name: String,
		desc: String,
		url: String,
		icon: String
	) -> some View {
		Button {
			UIApplication.open(url)
		} label: {
			HStack(spacing: 14) {
				Image(systemName: icon)
					.font(.system(size: 20, weight: .semibold))
					.foregroundColor(.white)
					.frame(width: 40, height: 40)
					.background(Color.blue)
					.clipShape(Circle())
				
				VStack(alignment: .leading, spacing: 2) {
					Text(name)
						.font(.headline)
						.foregroundStyle(Color.primary)
					Text(desc)
						.font(.subheadline)
						.foregroundStyle(Color.secondary)
				}
				
				Spacer()
				
				Image(systemName: "arrow.up.right")
					.foregroundColor(.secondary.opacity(0.65))
			}
		}
	}
}
