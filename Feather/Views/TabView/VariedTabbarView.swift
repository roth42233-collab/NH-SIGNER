//
//  VariedTabbarView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI

struct VariedTabbarView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	
	init() {}
	
	var body: some View {
		if #available(iOS 18, *), horizontalSizeClass == .regular {
			ExtendedTabbarView()
		} else {
			TabbarView()
		}
	}
}
