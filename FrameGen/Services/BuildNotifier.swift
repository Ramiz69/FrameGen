//
//  BuildNotifier.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit
import UserNotifications

/// Tells the user a build finished while they were working in another app.
/// Builds take minutes, so this is the one event worth a notification.
final class BuildNotifier {

    enum Outcome {
        case succeeded(projectName: String, frameworkName: String)
        case failed(projectName: String, title: String)
    }

    private var didRequestAuthorization = false

    /// Asks once, when the first build starts: the moment the notification's purpose is obvious.
    func requestAuthorizationIfNeeded() {
        guard Preferences.notifyWhenDone, !didRequestAuthorization else { return }

        didRequestAuthorization = true
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    func notify(_ outcome: Outcome) {
        guard Preferences.notifyWhenDone, !NSApp.isActive else { return }

        let content = UNMutableNotificationContent()
        switch outcome {
        case let .succeeded(projectName, frameworkName):
            content.title = String(localized: "\(frameworkName).xcframework is ready")
            content.body = String(localized: "The build of \(projectName) finished.")
            content.sound = .default
        case let .failed(projectName, title):
            content.title = title
            content.body = String(localized: "The build of \(projectName) failed. Open FrameGen to see the errors.")
            content.sound = .defaultCritical
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

}
