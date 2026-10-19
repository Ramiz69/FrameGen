//
//  AppDelegate.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 08.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private let workspace = Workspace()
    private lazy var mainWindowController = MainWindowController(workspace: workspace)
    private lazy var settingsWindowController = SettingsWindowController()

    // MARK: - NSApplicationDelegate

    func applicationWillFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        mainWindowController.showWindow(self)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        mainWindowController.showWindow(self)
        mainWindowController.openProject(at: url)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        mainWindowController.confirmStoppingBuild(action: "Quit") ? .terminateNow : .terminateCancel
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Actions

    @objc
    func showSettings(_ sender: Any?) {
        settingsWindowController.showWindow(sender)
    }

}
