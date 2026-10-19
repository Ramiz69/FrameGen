//
//  SettingsViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 26.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit

final class SettingsWindowController: NSWindowController {

    init() {
        let window = NSWindow(contentViewController: SettingsViewController())
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SettingsWindow")
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible == false {
            window?.center()
        }
        super.showWindow(sender)
    }

}

/// App-wide defaults: where results go and what happens after a build.
final class SettingsViewController: NSViewController {

    // MARK: - Properties

    private let defaults = UserDefaults.standard
    private let insideProjectRadio = NSButton(radioButtonWithTitle: "In a “build” folder next to the project", target: nil, action: nil)
    private let customFolderRadio = NSButton(radioButtonWithTitle: "In a shared folder:", target: nil, action: nil)
    private let customPathControl = NSPathControl()
    private let chooseButton = NSButton()
    private let revealCheckbox = NSButton(checkboxWithTitle: "Show the XCFramework in Finder", target: nil, action: nil)
    private let keepArchivesCheckbox = NSButton(checkboxWithTitle: "Keep intermediate archives", target: nil, action: nil)

    // MARK: - Life cycle

    override func loadView() {
        [insideProjectRadio, customFolderRadio].forEach {
            $0.target = self
            $0.action = #selector(didChangeLocation(_:))
        }
        customPathControl.pathStyle = .standard
        customPathControl.isEditable = false
        customPathControl.backgroundColor = .clear
        customPathControl.translatesAutoresizingMaskIntoConstraints = false
        customPathControl.setAccessibilityLabel("Shared output folder")
        chooseButton.title = "Choose…"
        chooseButton.bezelStyle = .push
        chooseButton.target = self
        chooseButton.action = #selector(chooseFolder(_:))
        [revealCheckbox, keepArchivesCheckbox].forEach {
            $0.target = self
            $0.action = #selector(didToggleOption(_:))
        }

        let locationHint = NSTextField.text("A project can override this in its Output section. Results go to a subfolder named after the project.",
                                            font: .preferred(.footnote), color: .secondaryLabelColor, lines: 0)
        locationHint.preferredMaxLayoutWidth = 380
        let customRow = NSStackView.horizontal([customPathControl, chooseButton])
        customPathControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        let archivesHint = NSTextField.text("Archives are needed only to rebuild the XCFramework by hand. dSYMs are already inside the XCFramework.",
                                            font: .preferred(.footnote), color: .secondaryLabelColor, lines: 0)
        archivesHint.preferredMaxLayoutWidth = 380

        let grid = NSGridView(views: [[label("Save results:"), insideProjectRadio],
                                      [NSGridCell.emptyContentView, customFolderRadio],
                                      [NSGridCell.emptyContentView, customRow],
                                      [NSGridCell.emptyContentView, locationHint],
                                      [label("After building:"), revealCheckbox],
                                      [NSGridCell.emptyContentView, keepArchivesCheckbox],
                                      [NSGridCell.emptyContentView, archivesHint]])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.columnSpacing = Metrics.spacing
        grid.rowSpacing = Metrics.spacing
        grid.row(at: 4).topPadding = Metrics.groupSpacing
        grid.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(grid)
        grid.pinEdges(to: root, insets: NSEdgeInsets(top: Metrics.margin, left: Metrics.margin + 10,
                                                     bottom: Metrics.margin, right: Metrics.margin + 10))
        view = root
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        update()
    }

    // MARK: - Private methods

    private func label(_ text: String) -> NSTextField {
        let label = NSTextField.text(text)
        label.alignment = .right

        return label
    }

    private var customPath: String? {
        defaults.string(forKey: PreferenceKey.customOutputPath).flatMap { $0.isEmpty ? nil : $0 }
    }

    private func update() {
        let location = OutputLocation(rawValue: defaults.string(forKey: PreferenceKey.outputLocation) ?? "") ?? .insideProject
        insideProjectRadio.state = location == .insideProject ? .on : .off
        customFolderRadio.state = location == .customFolder ? .on : .off
        customPathControl.url = customPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        customPathControl.placeholderString = "No folder chosen"
        customPathControl.isEnabled = location == .customFolder
        chooseButton.isEnabled = location == .customFolder
        revealCheckbox.state = defaults.bool(forKey: PreferenceKey.revealInFinder) ? .on : .off
        keepArchivesCheckbox.state = defaults.bool(forKey: PreferenceKey.keepArchives) ? .on : .off
    }

    // MARK: - Actions

    @objc
    private func didChangeLocation(_ sender: NSButton) {
        let location: OutputLocation = sender === customFolderRadio ? .customFolder : .insideProject
        defaults.set(location.rawValue, forKey: PreferenceKey.outputLocation)
        if location == .customFolder, customPath == nil {
            chooseFolder(sender)
        }
        update()
    }

    @objc
    private func chooseFolder(_ sender: Any?) {
        let current = customPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let url = ProjectLocator.chooseFolder(title: "Choose a Folder for Results", startingAt: current) {
            defaults.set(url.path, forKey: PreferenceKey.customOutputPath)
        } else if customPath == nil {
            defaults.set(OutputLocation.insideProject.rawValue, forKey: PreferenceKey.outputLocation)
        }
        update()
    }

    @objc
    private func didToggleOption(_ sender: NSButton) {
        let key = sender === revealCheckbox ? PreferenceKey.revealInFinder : PreferenceKey.keepArchives
        defaults.set(sender.state == .on, forKey: key)
    }

}
