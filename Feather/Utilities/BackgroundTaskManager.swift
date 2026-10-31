//
//  BackgroundTaskManager.swift
//  Feather
//
//  Created by Nagata Asami on 4/1/26.
//

#if !targetEnvironment(macCatalyst)

import Foundation
import UIKit
import CryptoKit

class BackgroundTaskManager: ObservableObject {
	static let shared = BackgroundTaskManager()
	
	private var bgTasks: [String: UIBackgroundTaskIdentifier] = [:]
	
	func startTask(for downloadId: String, filename: String) {
		stopTask(for: downloadId, success: false)
		
		var taskId: UIBackgroundTaskIdentifier = .invalid
		taskId = UIApplication.shared.beginBackgroundTask(withName: filename) { [weak self] in
			self?.stopTask(for: downloadId, success: false)
		}
		bgTasks[downloadId] = taskId
	}
	
	func updateProgress(for downloadId: String, progress: Double) {
		// Live progress update not applicable to standard UIBackgroundTaskIdentifier
	}
	
	func stopTask(for downloadId: String, success: Bool) {
		if let taskId = bgTasks[downloadId], taskId != .invalid {
			UIApplication.shared.endBackgroundTask(taskId)
			bgTasks.removeValue(forKey: downloadId)
		}
	}
}

extension String {
	var md5: String {
		Insecure.MD5.hash(data: Data(self.utf8)).map { String(format: "%02hhx", $0) }.joined()
	}
}

#endif
