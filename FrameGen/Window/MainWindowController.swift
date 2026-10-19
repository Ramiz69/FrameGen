//
//  MainWindowController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Owns the main window, its toolbar and the project commands from the menu bar.
/// It sits in the responder chain of the window, so menu items reach it whatever view has focus.
final class MainWindowController: NSWindowController {

    // MARK: - Properties

    private enum ToolbarItem {
        static let closeProject = NSToolbarItem.Identifier("closeProject")
        static let build = NSToolbarItem.Identifier("build")
        static let stop = NSToolbarItem.Identifier("stop")
        static let showInFinder = NSToolbarItem.Identifier("showInFinder")
    }

    private let workspace: Workspace
    private let buildController = BuildController()
    private var observation: ObservationLoop?

    private var project: Project? {
        workspace.project
    }

    // MARK: - Initial methods

    init(workspace: Workspace) {
        self.workspace = workspace
        super.init(window: MainWindow())

        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        window?.toolbar = toolbar
        contentViewController = RootViewController(workspace: workspace, buildController: buildController)
        (window as? MainWindow)?.restoreFrame()

        observation = ObservationLoop { [weak self] in
            self?.updateWindow()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func openProject(at url: URL) {
        guard confirmStoppingBuild(action: "Open") else { return }

        do {
            buildController.cancel()
            try workspace.open(url)
        } catch {
            presentError(error, modalFor: window!, delegate: nil, didPresent: nil, contextInfo: nil)
        }
    }

    /// Asks before interrupting a running build; returns whether the caller may continue.
    func confirmStoppingBuild(action: String) -> Bool {
        guard let project, project.build.isRunning else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Stop building \(project.name)?"
        alert.informativeText = "The XCFramework build in progress will be stopped."
        alert.addButton(withTitle: "Stop and \(action)")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        buildController.cancel()

        return true
    }

    // MARK: - Actions

    @objc
    func openDocument(_ sender: Any?) {
        guard let url = ProjectLocator.chooseProject() else { return }

        openProject(at: url)
    }

    @objc
    func openRecentProject(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }

        openProject(at: url)
    }

    @objc
    func clearRecentProjects(_ sender: Any?) {
        workspace.clearRecentProjects()
    }

    @objc
    func closeProject(_ sender: Any?) {
        guard confirmStoppingBuild(action: "Close") else { return }

        workspace.closeProject()
    }

    @objc
    func buildXCFramework(_ sender: Any?) {
        guard let project else { return }

        buildController.start(project)
    }

    @objc
    func stopBuild(_ sender: Any?) {
        buildController.cancel()
    }

    @objc
    func showOutputInFinder(_ sender: Any?) {
        guard let project else { return }

        if case .succeeded(let summary) = project.build.phase {
            NSWorkspace.shared.activateFileViewerSelecting([summary.plan.xcframeworkURL])
        } else {
            NSWorkspace.shared.reveal(project.outputDirectory)
        }
    }

    // MARK: - Private methods

    private func updateWindow() {
        guard let window else { return }

        if let project {
            window.title = project.name
            window.subtitle = Formatters.path(project.fileURL.deletingLastPathComponent())
            window.representedURL = project.fileURL
            // Read the build state so the toolbar re-validates when a build starts or ends.
            _ = project.canBuild
        } else {
            window.title = "FrameGen"
            window.subtitle = ""
            window.representedURL = nil
        }
        window.toolbar?.validateVisibleItems()
    }

    private func isEnabled(_ action: Selector?) -> Bool {
        switch action {
        case #selector(closeProject(_:)), #selector(showOutputInFinder(_:)):
            return project != nil
        case #selector(buildXCFramework(_:)):
            return project?.canBuild == true
        case #selector(stopBuild(_:)):
            return project?.build.isRunning == true
        case #selector(clearRecentProjects(_:)):
            return !workspace.recentProjects.isEmpty
        default:
            return true
        }
    }

}

// MARK: - NSMenuItemValidation, NSToolbarItemValidation

extension MainWindowController: NSMenuItemValidation, NSToolbarItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        isEnabled(menuItem.action)
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        isEnabled(item.action)
    }

}

// MARK: - NSToolbarDelegate

extension MainWindowController: NSToolbarDelegate {

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ToolbarItem.closeProject, .flexibleSpace, ToolbarItem.showInFinder, ToolbarItem.stop, ToolbarItem.build]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.space]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case ToolbarItem.closeProject:
            return item(itemIdentifier, label: "Projects", symbol: "chevron.backward",
                        toolTip: "Close the project and show recent projects (⇧⌘W)", action: #selector(closeProject(_:)))
        case ToolbarItem.build:
            return item(itemIdentifier, label: "Build", symbol: "play.fill",
                        toolTip: "Build the XCFramework (⌘B)", action: #selector(buildXCFramework(_:)))
        case ToolbarItem.stop:
            return item(itemIdentifier, label: "Stop", symbol: "stop.fill",
                        toolTip: "Stop the build (⌘.)", action: #selector(stopBuild(_:)))
        case ToolbarItem.showInFinder:
            return item(itemIdentifier, label: "Show in Finder", symbol: "folder",
                        toolTip: "Show the output folder in Finder (⇧⌘R)", action: #selector(showOutputInFinder(_:)))
        default:
            return nil
        }
    }

    private func item(_ identifier: NSToolbarItem.Identifier,
                      label: String,
                      symbol: String,
                      toolTip: String,
                      action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = toolTip
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.isBordered = true
        item.target = self
        item.action = action

        return item
    }

}
