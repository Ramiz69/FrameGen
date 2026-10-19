//
//  ConfigurationViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// The build options of a project: scheme, configuration, platforms and output folder.
final class ConfigurationViewController: NSViewController {

    // MARK: - Properties

    private let project: Project
    private var observation: ObservationLoop?

    private let contentView = ScrollingContentView()
    private let buildSection = FormSectionView(title: "Build")
    private let platformsSection = FormSectionView(title: "Platforms")
    private let outputSection = FormSectionView(title: "Output")
    private let statusContainer = NSStackView.vertical([], alignment: .leading)

    private let schemePopUp = NSPopUpButton()
    private let configurationPopUp = NSPopUpButton()
    private var platformSwitches: [Platform: NSSwitch] = [:]
    private let outputPathControl = NSPathControl()
    private let resetOutputButton = NSButton()
    private let summaryLabel = NSTextField.text(color: .secondaryLabelColor)
    private let buildButton = NSButton()
    private var shownInfoState: Project.InfoState?

    // MARK: - Initial methods

    init(project: Project) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        configureBuildSection()
        configurePlatformsSection()
        configureOutputSection()

        buildButton.title = "Build XCFramework"
        buildButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        buildButton.imagePosition = .imageLeading
        buildButton.bezelStyle = .push
        buildButton.controlSize = .large
        buildButton.keyEquivalent = "\r"
        buildButton.action = #selector(MainWindowController.buildXCFramework(_:))
        buildButton.toolTip = "Build the XCFramework (⌘B)"

        contentView.stackView.addFullWidthArrangedSubview(statusContainer)
        [buildSection, platformsSection, outputSection].forEach(contentView.stackView.addFullWidthArrangedSubview)
        contentView.setBottomBar(leading: [summaryLabel], trailing: [buildButton])
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        observation = ObservationLoop { [weak self] in
            self?.update()
        }
        // The default output folder comes from Settings, which is stored in UserDefaults rather than the model.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(defaultsDidChange(_:)),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        observation?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Private methods

    private func configureBuildSection() {
        schemePopUp.target = self
        schemePopUp.action = #selector(didSelectScheme(_:))
        schemePopUp.setAccessibilityLabel("Scheme")
        configurationPopUp.target = self
        configurationPopUp.action = #selector(didSelectConfiguration(_:))
        configurationPopUp.setAccessibilityLabel("Configuration")
        [schemePopUp, configurationPopUp].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        }
        buildSection.setRows([FormRowView(title: "Scheme", accessory: schemePopUp),
                              FormRowView(title: "Configuration", accessory: configurationPopUp)])
    }

    private func configurePlatformsSection() {
        let rows = Platform.allCases.map { platform in
            let toggle = NSSwitch()
            toggle.target = self
            toggle.action = #selector(didTogglePlatform(_:))
            toggle.setAccessibilityLabel(platform.title)
            platformSwitches[platform] = toggle

            return FormRowView(title: platform.title, subtitle: platform.detail, symbol: platform.systemImage, accessory: toggle)
        }
        platformsSection.setRows(rows)
        platformsSection.footer = "Each platform is archived separately and becomes one slice of the XCFramework."
    }

    private func configureOutputSection() {
        outputPathControl.pathStyle = .standard
        outputPathControl.isEditable = false
        outputPathControl.backgroundColor = .clear
        outputPathControl.translatesAutoresizingMaskIntoConstraints = false
        outputPathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        outputPathControl.target = self
        outputPathControl.doubleAction = #selector(showOutputFolder(_:))
        outputPathControl.setAccessibilityLabel("Output folder")

        let chooseButton = NSButton.push("Choose…", target: self, action: #selector(chooseOutputFolder(_:)))
        resetOutputButton.title = "Use Default"
        resetOutputButton.bezelStyle = .push
        resetOutputButton.target = self
        resetOutputButton.action = #selector(resetOutputFolder(_:))
        resetOutputButton.toolTip = "Use the location from Settings"
        let buttons = NSStackView.horizontal([resetOutputButton, chooseButton])

        let folderRow = FormRowView(title: "Folder", accessory: buttons)
        let pathContainer = NSView()
        pathContainer.translatesAutoresizingMaskIntoConstraints = false
        pathContainer.addSubview(outputPathControl)
        outputPathControl.pinEdges(to: pathContainer, insets: NSEdgeInsets(top: 0, left: 8, bottom: 10, right: 12))
        outputSection.setRows([folderRow, pathContainer])
    }

    private func update() {
        updateStatus()

        let isLoaded = project.infoState == .loaded
        reloadItems(of: schemePopUp, with: project.schemes, selected: project.scheme)
        reloadItems(of: configurationPopUp, with: project.configurations, selected: project.configuration)
        schemePopUp.isEnabled = isLoaded
        configurationPopUp.isEnabled = isLoaded

        for (platform, toggle) in platformSwitches {
            toggle.state = project.platforms.contains(platform) ? .on : .off
        }

        outputPathControl.url = project.outputDirectory
        resetOutputButton.isHidden = project.customOutputDirectory == nil
        outputSection.footer = "Contains the .xcframework, its zip archive and a SwiftPM binaryTarget snippet. "
            + "Intermediate archives go to the Archives subfolder."

        buildButton.isEnabled = project.canBuild
        summaryLabel.stringValue = summary()
    }

    private func updateStatus() {
        guard project.infoState != shownInfoState else { return }

        shownInfoState = project.infoState
        statusContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch project.infoState {
        case .loading:
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.startAnimation(nil)
            let label = NSTextField.text("Reading schemes and configurations…", color: .secondaryLabelColor)
            statusContainer.addFullWidthArrangedSubview(NSStackView.horizontal([spinner, label, .spacer()]))
        case .loaded:
            break
        case .failed(let message):
            let retry = NSButton.push("Try Again", target: self, action: #selector(reloadProject(_:)))
            statusContainer.addFullWidthArrangedSubview(CalloutView(style: .error,
                                                           title: "Couldn’t read the project",
                                                           message: message,
                                                           action: retry))
        }
        statusContainer.isHidden = statusContainer.arrangedSubviews.isEmpty
    }

    private func reloadItems(of popUp: NSPopUpButton, with titles: [String], selected: String?) {
        if popUp.itemTitles != titles {
            popUp.removeAllItems()
            popUp.addItems(withTitles: titles)
        }
        if let selected, titles.contains(selected) {
            popUp.selectItem(withTitle: selected)
        }
    }

    private func summary() -> String {
        guard project.infoState == .loaded, let scheme = project.scheme, let configuration = project.configuration else {
            return ""
        }
        guard !project.platforms.isEmpty else {
            return "Turn on at least one platform."
        }

        let count = project.platforms.count

        return "\(scheme) · \(configuration) · \(count) platform\(count == 1 ? "" : "s")"
    }

    // MARK: - Actions

    @objc
    private func didSelectScheme(_ sender: NSPopUpButton) {
        project.scheme = sender.titleOfSelectedItem
    }

    @objc
    private func didSelectConfiguration(_ sender: NSPopUpButton) {
        project.configuration = sender.titleOfSelectedItem
    }

    @objc
    private func didTogglePlatform(_ sender: NSSwitch) {
        guard let platform = platformSwitches.first(where: { $0.value === sender })?.key else { return }

        if sender.state == .on {
            project.platforms.insert(platform)
        } else {
            project.platforms.remove(platform)
        }
    }

    @objc
    private func chooseOutputFolder(_ sender: Any?) {
        guard let url = ProjectLocator.chooseFolder(title: "Choose Output Folder", startingAt: project.outputDirectory) else { return }

        project.customOutputDirectory = url
    }

    @objc
    private func resetOutputFolder(_ sender: Any?) {
        project.customOutputDirectory = nil
    }

    @objc
    private func showOutputFolder(_ sender: Any?) {
        NSWorkspace.shared.reveal(project.outputDirectory)
    }

    @objc
    private func defaultsDidChange(_ notification: Notification) {
        update()
    }

    @objc
    private func reloadProject(_ sender: Any?) {
        Task {
            await project.loadInfo()
        }
    }

}
