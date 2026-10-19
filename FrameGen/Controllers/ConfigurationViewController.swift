//
//  ConfigurationViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit
import FrameGenKit

/// The build options of a project: scheme, version, platforms, signing, output and distribution.
final class ConfigurationViewController: NSViewController {

    // MARK: - Properties

    private let project: Project
    private var observation: ObservationLoop?

    private let contentView = ScrollingContentView()
    private let statusContainer = NSStackView.vertical([], alignment: .leading)
    private let buildSection = FormSectionView(title: String(localized: "Build"))
    private let platformsSection = FormSectionView(title: String(localized: "Platforms"))
    private let signingSection = FormSectionView(title: String(localized: "Signing"))
    private let outputSection = FormSectionView(title: String(localized: "Output"))
    private let distributionSection = FormSectionView(title: String(localized: "Distribution"))

    private let schemePopUp = NSPopUpButton()
    private let configurationPopUp = NSPopUpButton()
    private let versionField = NSTextField()
    private var platformSwitches: [Platform: NSSwitch] = [:]
    private let identityPopUp = NSPopUpButton()
    private let outputPathControl = NSPathControl()
    private let resetOutputButton = NSButton()
    private let distributionPopUp = NSPopUpButton()
    private let downloadURLField = NSTextField()
    private let publishCommandField = NSTextField()
    private let tagField = NSTextField()
    private let draftCheckbox = NSButton(checkboxWithTitle: String(localized: "Create as a draft"), target: nil, action: nil)
    private let summaryLabel = NSTextField.text(color: .secondaryLabelColor)
    private let buildButton = NSButton()

    private var shownStatus: [String] = []
    private var shownPlatformState: (Project.LoadState, Set<Platform>)?
    private var shownIdentities: [SigningIdentity]?
    private var shownDistribution: (DistributionMode, GitRemote?)?

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
        configureControls()
        configureBuildSection()
        configureOutputSection()

        buildButton.title = String(localized: "Build XCFramework")
        buildButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        buildButton.imagePosition = .imageLeading
        buildButton.bezelStyle = .push
        buildButton.controlSize = .large
        buildButton.keyEquivalent = "\r"
        buildButton.action = #selector(MainWindowController.buildXCFramework(_:))
        buildButton.toolTip = String(localized: "Build the XCFramework (⌘B)")

        let copyCommandButton = NSButton.push(String(localized: "Copy Command"), symbol: "terminal", target: nil,
                                              action: #selector(MainWindowController.copyBuildCommand(_:)))
        copyCommandButton.toolTip = String(localized: "Copy the equivalent framegen command for CI (⌥⌘C)")

        contentView.stackView.addFullWidthArrangedSubview(statusContainer)
        [buildSection, platformsSection, signingSection, outputSection, distributionSection]
            .forEach(contentView.stackView.addFullWidthArrangedSubview)
        contentView.setBottomBar(leading: [copyCommandButton, summaryLabel], trailing: [buildButton])
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

    // MARK: - Configuration

    private func configureControls() {
        for popUp in [schemePopUp, configurationPopUp, identityPopUp, distributionPopUp] {
            popUp.translatesAutoresizingMaskIntoConstraints = false
            popUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
            popUp.target = self
        }
        schemePopUp.action = #selector(didSelectScheme(_:))
        schemePopUp.setAccessibilityLabel(String(localized: "Scheme"))
        configurationPopUp.action = #selector(didSelectConfiguration(_:))
        configurationPopUp.setAccessibilityLabel(String(localized: "Configuration"))
        identityPopUp.action = #selector(didSelectIdentity(_:))
        identityPopUp.setAccessibilityLabel(String(localized: "Signing identity"))
        distributionPopUp.action = #selector(didSelectDistribution(_:))
        distributionPopUp.setAccessibilityLabel(String(localized: "Distribution"))
        distributionPopUp.addItems(withTitles: [String(localized: "Upload manually"),
                                                String(localized: "GitHub Release"),
                                                String(localized: "Custom command")])

        for field in [versionField, downloadURLField, publishCommandField, tagField] {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.delegate = self
            field.lineBreakMode = .byTruncatingTail
            field.usesSingleLineMode = true
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        }
        versionField.setAccessibilityLabel(String(localized: "Version"))
        downloadURLField.placeholderString = "https://cdn.example.com/{name}/{version}/{zip}"
        downloadURLField.setAccessibilityLabel(String(localized: "Download URL"))
        downloadURLField.font = .monospaced(.callout)
        publishCommandField.placeholderString = #"aws s3 cp {path} "s3://bucket/{name}/{version}/{zip}""#
        publishCommandField.setAccessibilityLabel(String(localized: "Upload command"))
        publishCommandField.font = .monospaced(.callout)
        tagField.setAccessibilityLabel(String(localized: "Release tag"))
        tagField.font = .monospaced(.callout)
        draftCheckbox.target = self
        draftCheckbox.action = #selector(didToggleDraft(_:))
    }

    private func configureBuildSection() {
        buildSection.setRows([FormRowView(title: String(localized: "Scheme"), accessory: schemePopUp),
                              FormRowView(title: String(localized: "Configuration"), accessory: configurationPopUp),
                              FormRowView(title: String(localized: "Version"),
                                          subtitle: String(localized: "Used by {version} in URLs and release tags"),
                                          accessory: versionField)])
    }

    private func configureOutputSection() {
        outputPathControl.pathStyle = .standard
        outputPathControl.isEditable = false
        outputPathControl.backgroundColor = .clear
        outputPathControl.translatesAutoresizingMaskIntoConstraints = false
        outputPathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        outputPathControl.target = self
        outputPathControl.doubleAction = #selector(showOutputFolder(_:))
        outputPathControl.setAccessibilityLabel(String(localized: "Output folder"))

        let chooseButton = NSButton.push(String(localized: "Choose…"), target: self, action: #selector(chooseOutputFolder(_:)))
        resetOutputButton.title = String(localized: "Use Default")
        resetOutputButton.bezelStyle = .push
        resetOutputButton.target = self
        resetOutputButton.action = #selector(resetOutputFolder(_:))
        resetOutputButton.toolTip = String(localized: "Use the location from Settings")

        let folderRow = FormRowView(title: String(localized: "Folder"), accessory: NSStackView.horizontal([resetOutputButton, chooseButton]))
        outputSection.setRows([folderRow, inset(outputPathControl)])
        outputSection.footer = String(localized: "Contains the .xcframework, its zip archive and a SwiftPM binaryTarget snippet. Intermediate archives go to the Archives subfolder.")
    }

    // MARK: - Updates

    private func update() {
        updateStatus()

        let isLoaded = project.infoState == .loaded
        reloadItems(of: schemePopUp, with: project.schemes, selected: project.scheme)
        reloadItems(of: configurationPopUp, with: project.configurations, selected: project.configuration)
        schemePopUp.isEnabled = isLoaded && !project.build.isRunning
        configurationPopUp.isEnabled = isLoaded
        versionField.placeholderString = project.schemeInfo?.marketingVersion ?? "1.0"
        if versionField.currentEditor() == nil {
            versionField.stringValue = project.customVersion ?? ""
        }

        updatePlatforms()
        updateSigning()

        outputPathControl.url = project.outputDirectory
        resetOutputButton.isHidden = project.customOutputDirectory == nil

        updateDistribution()

        buildButton.isEnabled = project.canBuild
        summaryLabel.stringValue = summary()
    }

    private func updateStatus() {
        var messages: [(title: String, message: String, retry: Bool)] = []
        if case .failed(let message) = project.infoState {
            messages.append((String(localized: "Couldn’t read the project"), message, true))
        } else if case .failed(let message) = project.schemeInfoState {
            messages.append((String(localized: "Couldn’t read the scheme’s build settings"), message, true))
        }
        let key = messages.map(\.message) + [project.infoState == .loading ? "loading" : ""]
        guard key != shownStatus else { return }

        shownStatus = key
        statusContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if project.infoState == .loading {
            statusContainer.addFullWidthArrangedSubview(spinnerRow(String(localized: "Reading schemes and configurations…")))
        }
        for message in messages {
            let retry = NSButton.push(String(localized: "Try Again"), target: self, action: #selector(reloadProject(_:)))
            statusContainer.addFullWidthArrangedSubview(CalloutView(style: .error, title: message.title, message: message.message, action: retry))
        }
        statusContainer.isHidden = statusContainer.arrangedSubviews.isEmpty
    }

    private func updatePlatforms() {
        let state = (project.schemeInfoState, project.supportedPlatforms)
        if shownPlatformState.map({ $0.0 != state.0 || $0.1 != state.1 }) ?? true {
            shownPlatformState = state
            platformSwitches = [:]
            switch project.schemeInfoState {
            case .loading:
                platformsSection.setRows([inset(spinnerRow(String(localized: "Detecting supported platforms…")))])
                platformsSection.footer = nil
            case .failed:
                platformsSection.setRows([inset(NSTextField.text(String(localized: "Platforms appear once the scheme’s build settings are read."),
                                                                  color: .secondaryLabelColor, lines: 0))])
                platformsSection.footer = nil
            case .loaded:
                let supported = Platform.allCases.filter(project.supportedPlatforms.contains)
                platformsSection.setRows(supported.map { platform in
                    let toggle = NSSwitch()
                    toggle.target = self
                    toggle.action = #selector(didTogglePlatform(_:))
                    toggle.setAccessibilityLabel(platform.title)
                    platformSwitches[platform] = toggle

                    return FormRowView(title: platform.title, subtitle: platform.detail, symbol: platform.systemImage, accessory: toggle)
                })
                let unsupported = Platform.Family.allCases
                    .filter { family in !supported.contains { $0.family == family } }
                    .map(\.title)
                platformsSection.footer = unsupported.isEmpty
                    ? String(localized: "Each platform is archived separately and becomes one slice of the XCFramework.")
                    : String(localized: "Each platform is archived separately and becomes one slice of the XCFramework. Not supported by this scheme: \(unsupported.formatted(.list(type: .and))).")
            }
        }
        let selected = Set(project.selectedPlatforms)
        for (platform, toggle) in platformSwitches {
            toggle.state = selected.contains(platform) ? .on : .off
        }
    }

    private func updateSigning() {
        if shownIdentities != project.signingIdentities {
            shownIdentities = project.signingIdentities
            identityPopUp.removeAllItems()
            identityPopUp.addItem(withTitle: String(localized: "Don’t Sign"))
            for identity in project.signingIdentities {
                identityPopUp.addItem(withTitle: identity.name)
                identityPopUp.lastItem?.representedObject = identity.sha1
                identityPopUp.lastItem?.toolTip = identity.sha1
            }
            signingSection.setRows([FormRowView(title: String(localized: "Identity"), symbol: "signature", accessory: identityPopUp)])
            signingSection.footer = project.signingIdentities.isEmpty
                ? String(localized: "No signing certificates were found in the keychain.")
                : String(localized: "Apps that embed the XCFramework can verify who built it. Apple requires signatures for commonly used SDKs. Signing needs a network connection for the timestamp.")
        }
        if let identity = project.signingIdentity, let index = project.signingIdentities.firstIndex(of: identity) {
            identityPopUp.selectItem(at: index + 1)
        } else {
            identityPopUp.selectItem(at: 0)
        }
    }

    private func updateDistribution() {
        let state = (project.distribution, project.gitRemote)
        if shownDistribution.map({ $0.0 != state.0 || $0.1 != state.1 }) ?? true {
            shownDistribution = state
            var rows: [NSView] = [FormRowView(title: String(localized: "Publish"), symbol: "shippingbox", accessory: distributionPopUp)]
            switch project.distribution {
            case .manual:
                rows.append(FormRowView(title: String(localized: "Download URL"),
                                        subtitle: String(localized: "Optional; fills the binaryTarget snippet"),
                                        accessory: downloadURLField))
                distributionSection.footer = String(localized: "Upload the zip anywhere SwiftPM can download it over HTTPS. Placeholders: {name}, {version}, {zip}.")
            case .gitHubRelease:
                let repository = project.gitRemote.map { "\($0.host)/\($0.path)" } ?? String(localized: "No GitHub remote")
                rows.append(FormRowView(title: String(localized: "Repository"), subtitle: repository, symbol: nil, accessory: nil))
                rows.append(FormRowView(title: String(localized: "Release tag"), accessory: tagField))
                rows.append(FormRowView(title: String(localized: "Draft"), accessory: draftCheckbox))
                distributionSection.footer = project.gitRemote?.isGitHub == false
                    ? String(localized: "The origin remote isn’t on github.com; GitHub CLI must be signed in to that host.")
                    : String(localized: "Uses GitHub CLI (gh). The release is created if it doesn’t exist, otherwise the zip replaces its asset.")
            case .command:
                let presets = NSPopUpButton(frame: .zero, pullsDown: true)
                presets.addItem(withTitle: String(localized: "Fill from Preset"))
                for preset in PublishPreset.allCases {
                    presets.addItem(withTitle: preset.title)
                    presets.lastItem?.representedObject = preset.rawValue
                }
                presets.target = self
                presets.action = #selector(didChoosePreset(_:))
                rows.append(FormRowView(title: String(localized: "Upload command"),
                                        subtitle: String(localized: "Runs in zsh; {path} is the zip"),
                                        accessory: NSStackView.horizontal([publishCommandField, presets])))
                rows.append(FormRowView(title: String(localized: "Download URL"), accessory: downloadURLField))
                distributionSection.footer = String(localized: "Works with GitLab, Bitbucket, S3, Artifactory, Nexus or any internal server. Values are shell-quoted; define tokens in ~/.zprofile. Placeholders: {name}, {version}, {zip}, {path}, {checksum}.")
            }
            distributionSection.setRows(rows)
        }
        distributionPopUp.selectItem(at: DistributionMode.allCases.firstIndex(of: project.distribution) ?? 0)
        distributionPopUp.item(at: 1)?.isEnabled = project.gitRemote != nil
        distributionPopUp.autoenablesItems = false
        if downloadURLField.currentEditor() == nil {
            downloadURLField.stringValue = project.downloadURLTemplate
        }
        if publishCommandField.currentEditor() == nil {
            publishCommandField.stringValue = project.publishCommand
        }
        if tagField.currentEditor() == nil {
            tagField.stringValue = project.tagTemplate
        }
        draftCheckbox.state = project.publishAsDraft ? .on : .off
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
        guard project.schemeInfoState == .loaded else {
            return ""
        }
        guard !project.selectedPlatforms.isEmpty else {
            return String(localized: "Turn on at least one platform.")
        }

        return String(localized: "\(scheme) · \(configuration) · \(project.selectedPlatforms.count) platforms")
    }

    private func spinnerRow(_ text: String) -> NSView {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)

        return NSStackView.horizontal([spinner, NSTextField.text(text, color: .secondaryLabelColor), .spacer()])
    }

    private func inset(_ view: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        view.pinEdges(to: container, insets: NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))

        return container
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

        project.setPlatform(platform, isOn: sender.state == .on)
    }

    @objc
    private func didSelectIdentity(_ sender: NSPopUpButton) {
        let sha1 = sender.selectedItem?.representedObject as? String
        project.signingIdentity = project.signingIdentities.first { $0.sha1 == sha1 }
    }

    @objc
    private func didSelectDistribution(_ sender: NSPopUpButton) {
        project.distribution = DistributionMode.allCases[max(sender.indexOfSelectedItem, 0)]
    }

    @objc
    private func didChoosePreset(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String, let preset = PublishPreset(rawValue: rawValue) else { return }

        project.publishCommand = preset.commandTemplate
        project.downloadURLTemplate = preset.downloadURLTemplate
    }

    @objc
    private func didToggleDraft(_ sender: NSButton) {
        project.publishAsDraft = sender.state == .on
    }

    @objc
    private func chooseOutputFolder(_ sender: Any?) {
        guard let url = ProjectPicker.chooseFolder(title: String(localized: "Choose Output Folder"), startingAt: project.outputDirectory) else { return }

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

// MARK: - NSTextFieldDelegate

extension ConfigurationViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }

        let value = field.stringValue.trimmingCharacters(in: .whitespaces)
        switch field {
        case versionField:
            project.customVersion = value.isEmpty ? nil : value
        case downloadURLField:
            project.downloadURLTemplate = value
        case publishCommandField:
            project.publishCommand = value
        case tagField:
            project.tagTemplate = value.isEmpty ? "v{version}" : value
        default:
            break
        }
    }

}

extension PublishPreset {

    var title: String {
        switch self {
        case .gitLabPackageRegistry:
            return String(localized: "GitLab Package Registry")
        case .bitbucketDownloads:
            return String(localized: "Bitbucket Downloads")
        case .amazonS3:
            return "Amazon S3"
        case .artifactory:
            return "JFrog Artifactory"
        }
    }

}
