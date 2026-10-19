//
//  WelcomeViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit
import FrameGenKit

/// The start screen: what FrameGen does, how to open a project, and the recent projects.
final class WelcomeViewController: NSViewController {

    // MARK: - Properties

    private let workspace: Workspace
    private let openProject: (URL) -> Void
    private var observation: ObservationLoop?
    private var recentProjects: [ProjectContainer] = []

    private let tableView = NSTableView()
    private let emptyLabel = NSTextField.text(String(localized: "No Recent Projects"), font: .preferred(.title3), color: .tertiaryLabelColor)

    // MARK: - Initial methods

    init(workspace: Workspace, openProject: @escaping (URL) -> Void) {
        self.workspace = workspace
        self.openProject = openProject
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        let heroPane = makeHeroPane()
        let recentsPane = makeRecentsPane()
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        [heroPane, divider, recentsPane].forEach(root.addSubview)
        NSLayoutConstraint.activate([heroPane.leadingAnchor.constraint(equalTo: root.leadingAnchor),
                                     heroPane.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
                                     heroPane.bottomAnchor.constraint(equalTo: root.bottomAnchor),
                                     heroPane.widthAnchor.constraint(equalTo: root.widthAnchor, multiplier: 0.55),
                                     divider.leadingAnchor.constraint(equalTo: heroPane.trailingAnchor),
                                     divider.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
                                     divider.bottomAnchor.constraint(equalTo: root.bottomAnchor),
                                     recentsPane.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
                                     recentsPane.trailingAnchor.constraint(equalTo: root.trailingAnchor),
                                     recentsPane.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
                                     recentsPane.bottomAnchor.constraint(equalTo: root.bottomAnchor)])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        observation = ObservationLoop { [weak self] in
            self?.reloadRecentProjects()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(recentProjects.isEmpty ? nil : tableView)
        if tableView.selectedRow < 0, !recentProjects.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: - Private methods

    private func makeHeroPane() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 112),
                                     icon.heightAnchor.constraint(equalToConstant: 112)])
        icon.setAccessibilityElement(false)

        let title = NSTextField.text("FrameGen", font: .preferred(.largeTitle, weight: .bold))
        let subtitle = NSTextField.text(String(localized: "Turn an Xcode framework project into an XCFramework, a zip and a SwiftPM checksum."),
                                        font: .preferred(.body), color: .secondaryLabelColor, lines: 0)
        subtitle.alignment = .center
        subtitle.preferredMaxLayoutWidth = 300

        let openButton = NSButton.push(String(localized: "Open Project…"), target: nil, action: #selector(MainWindowController.openDocument(_:)))
        // Return opens the selected recent project, so this button relies on ⌘O instead of a default key equivalent.
        openButton.bezelColor = .controlAccentColor
        openButton.controlSize = .large

        let dropHint = makeDropHint()
        let stack = NSStackView.vertical([icon, title, subtitle, openButton, dropHint], spacing: 12, alignment: .centerX)
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(Metrics.groupSpacing, after: subtitle)
        stack.setCustomSpacing(Metrics.groupSpacing, after: openButton)

        let pane = NSView()
        pane.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: pane.centerXAnchor),
                                     stack.centerYAnchor.constraint(equalTo: pane.centerYAnchor),
                                     stack.leadingAnchor.constraint(greaterThanOrEqualTo: pane.leadingAnchor, constant: Metrics.margin)])

        return pane
    }

    private func makeDropHint() -> NSView {
        let icon = NSImageView.symbol("arrow.down.doc", pointSize: 22, color: .secondaryLabelColor)
        let label = NSTextField.text(String(localized: "or drop an .xcodeproj or its folder anywhere in this window"),
                                     font: .preferred(.callout), color: .secondaryLabelColor, lines: 0)
        label.alignment = .center
        label.preferredMaxLayoutWidth = 220
        let stack = NSStackView.vertical([icon, label], spacing: 6, alignment: .centerX)

        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = Metrics.cornerRadius
        box.borderColor = .separatorColor
        box.fillColor = .clear
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = false
        if let contentView = box.contentView {
            contentView.addSubview(stack)
            stack.pinEdges(to: contentView, insets: NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        }
        box.widthAnchor.constraint(equalToConstant: 280).isActive = true

        return box
    }

    private func makeRecentsPane() -> NSView {
        let header = NSTextField.text(String(localized: "Recent Projects"), font: .preferred(.headline), color: .secondaryLabelColor)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("project"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .inset
        tableView.rowHeight = 46
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(openClickedProject(_:))
        tableView.menu = makeContextMenu()
        tableView.setAccessibilityLabel(String(localized: "Recent projects"))

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let pane = NSVisualEffectView()
        pane.material = .sidebar
        pane.blendingMode = .behindWindow
        pane.translatesAutoresizingMaskIntoConstraints = false
        [header, scrollView, emptyLabel].forEach(pane.addSubview)
        NSLayoutConstraint.activate([header.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: Metrics.margin),
                                     header.topAnchor.constraint(equalTo: pane.topAnchor, constant: Metrics.margin),
                                     scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: Metrics.spacing),
                                     scrollView.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
                                     scrollView.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
                                     scrollView.bottomAnchor.constraint(equalTo: pane.bottomAnchor),
                                     emptyLabel.centerXAnchor.constraint(equalTo: pane.centerXAnchor),
                                     emptyLabel.centerYAnchor.constraint(equalTo: pane.centerYAnchor)])

        return pane
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Open"), action: #selector(openClickedProject(_:)), keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Show in Finder"), action: #selector(showClickedProjectInFinder(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Remove from Recent Projects"), action: #selector(removeClickedProject(_:)), keyEquivalent: "")
        menu.items.forEach { $0.target = self }

        return menu
    }

    private func reloadRecentProjects() {
        recentProjects = workspace.recentProjects
        tableView.reloadData()
        emptyLabel.isHidden = !recentProjects.isEmpty
    }

    /// The right-clicked row for context menu actions, otherwise the selected one.
    private var targetProject: ProjectContainer? {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow

        return recentProjects.indices.contains(row) ? recentProjects[row] : nil
    }

    // MARK: - Actions

    @objc
    private func openClickedProject(_ sender: Any?) {
        guard let container = targetProject else { return }

        openProject(container.url)
    }

    @objc
    private func showClickedProjectInFinder(_ sender: Any?) {
        guard let container = targetProject else { return }

        NSWorkspace.shared.activateFileViewerSelecting([container.url])
    }

    @objc
    private func removeClickedProject(_ sender: Any?) {
        guard let container = targetProject else { return }

        workspace.removeRecentProject(container)
    }

    override func keyDown(with event: NSEvent) {
        switch event.specialKey {
        case .carriageReturn, .enter:
            openClickedProject(nil)
        case .delete, .deleteForward:
            removeClickedProject(nil)
        default:
            super.keyDown(with: event)
        }
    }

}

// MARK: - NSTableViewDataSource, NSTableViewDelegate

extension WelcomeViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        recentProjects.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: RecentProjectCellView.identifier, owner: self) as? RecentProjectCellView
            ?? RecentProjectCellView()
        cell.configure(with: recentProjects[row].url)

        return cell
    }

}
