//
//  BuildResultViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit
import FrameGenKit

/// Shows what was built, publishes it, and gives everything needed for a SwiftPM binary target.
final class BuildResultViewController: NSViewController {

    // MARK: - Properties

    private let project: Project
    private let buildController: BuildController
    private let contentView = ScrollingContentView()
    private var observation: ObservationLoop?
    private var renderedState: (XCFrameworkBuilder.Summary, PublishState)?

    private static let privacyManifestURL = URL(string: "https://developer.apple.com/documentation/bundleresources/privacy-manifest-files")!

    // MARK: - Initial methods

    init(project: Project, buildController: BuildController) {
        self.project = project
        self.buildController = buildController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        observation = ObservationLoop { [weak self] in
            self?.render()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        observation?.cancel()
    }

    // MARK: - Private methods

    /// Rebuilt whenever publishing changes the snippet or its own status.
    private func render() {
        guard case .succeeded(let summary) = project.build.phase else { return }

        let publishState = project.build.publishState
        let destination = project.publishDestination
        if let renderedState, renderedState.0 == summary, renderedState.1 == publishState {
            return
        }
        renderedState = (summary, publishState)

        let stack = contentView.stackView
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let header = StatusHeaderView()
        header.setSymbol("checkmark.seal.fill", color: .systemGreen, accessibilityDescription: String(localized: "Succeeded"))
        header.titleLabel.stringValue = String(localized: "\(summary.plan.xcframeworkURL.lastPathComponent) is ready")
        var details = [String(localized: "Built in \(Formatters.duration(project.build.duration))"),
                       String(localized: "\(summary.plan.slices.count) platforms"),
                       String(localized: "\(Formatters.fileSize(summary.zipSize)) zipped")]
        if let signedBy = summary.signedBy {
            details.append(String(localized: "signed by \(signedBy)"))
        }
        header.subtitleLabel.stringValue = details.joined(separator: " · ")
        stack.addFullWidthArrangedSubview(header)

        if let callout = publishCallout(publishState) {
            stack.addFullWidthArrangedSubview(callout)
        }
        if !summary.librariesWithoutPrivacyManifest.isEmpty {
            let learnMore = NSButton.push(String(localized: "Learn About Privacy Manifests"), target: self, action: #selector(openPrivacyDocumentation(_:)))
            learnMore.bezelStyle = .inline
            stack.addFullWidthArrangedSubview(
                CalloutView(style: .warning,
                            title: String(localized: "No privacy manifest"),
                            message: String(localized: "PrivacyInfo.xcprivacy is missing in \(summary.librariesWithoutPrivacyManifest.joined(separator: ", ")). Apple requires privacy manifests in commonly used third-party SDKs."),
                            action: learnMore))
        }
        stack.addFullWidthArrangedSubview(makeFilesSection(summary))
        stack.addFullWidthArrangedSubview(makePackageSection(summary))

        let doneButton = NSButton.push(String(localized: "Done"), target: self, action: #selector(done(_:)))
        doneButton.controlSize = .large
        doneButton.keyEquivalent = "\u{1b}"
        let buildAgain = NSButton.push(String(localized: "Build Again"), target: nil, action: #selector(MainWindowController.buildXCFramework(_:)))
        buildAgain.controlSize = .large
        let showInFinder = NSButton.push(String(localized: "Show in Finder"), symbol: "folder", target: self, action: #selector(showInFinder(_:)))
        showInFinder.controlSize = .large
        var trailing: [NSView] = [buildAgain, showInFinder]
        if destination != nil {
            let publish = NSButton.push(publishTitle(destination), symbol: "arrow.up.circle", target: self, action: #selector(publish(_:)))
            publish.controlSize = .large
            publish.isEnabled = publishState != .publishing
            publish.keyEquivalent = "\r"
            trailing.append(publish)
        } else {
            showInFinder.keyEquivalent = "\r"
        }
        contentView.setBottomBar(leading: [doneButton], trailing: trailing)
    }

    private func publishTitle(_ destination: PublishDestination?) -> String {
        if case .gitHub? = destination {
            return String(localized: "Publish to GitHub")
        }

        return String(localized: "Publish")
    }

    private func publishCallout(_ state: PublishState) -> NSView? {
        switch state {
        case .idle:
            return nil
        case .publishing:
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.startAnimation(nil)

            return NSStackView.horizontal([spinner, NSTextField.text(String(localized: "Uploading…"), color: .secondaryLabelColor), .spacer()])
        case .published(let url):
            let open = NSButton.push(String(localized: "Copy URL"), target: self, action: #selector(copyDownloadURL(_:)))
            open.bezelStyle = .inline

            return CalloutView(style: .success,
                               title: String(localized: "Published"),
                               message: String(localized: "SwiftPM can download the zip from \(url.absoluteString). The snippet below uses this URL."),
                               action: open)
        case .failed(let message):
            let retry = NSButton.push(String(localized: "Try Again"), target: self, action: #selector(publish(_:)))

            return CalloutView(style: .error, title: String(localized: "Publishing failed"), message: message, action: retry)
        }
    }

    private func makeFilesSection(_ summary: XCFrameworkBuilder.Summary) -> NSView {
        let section = FormSectionView(title: String(localized: "Files"))
        let rows = [summary.plan.xcframeworkURL, summary.plan.zipURL, summary.plan.snippetURL].map { url in
            let reveal = NSButton(image: NSImage(systemSymbolName: "arrow.forward.circle.fill",
                                                 accessibilityDescription: String(localized: "Show in Finder"))!,
                                  target: self,
                                  action: #selector(revealFile(_:)))
            reveal.isBordered = false
            reveal.contentTintColor = .secondaryLabelColor
            reveal.toolTip = String(localized: "Show in Finder")
            reveal.identifier = NSUserInterfaceItemIdentifier(url.path)
            let row = FormRowView(title: url.lastPathComponent,
                                  subtitle: Formatters.path(url.deletingLastPathComponent()),
                                  accessory: reveal)
            row.toolTip = url.path

            return row
        }
        section.setRows(rows)

        return section
    }

    private func makePackageSection(_ summary: XCFrameworkBuilder.Summary) -> NSView {
        let section = FormSectionView(title: String(localized: "Swift Package Manager"))

        let checksumLabel = NSTextField.text(summary.checksum, font: .monospaced(.callout), selectable: true)
        checksumLabel.lineBreakMode = .byTruncatingMiddle
        checksumLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let copyChecksum = CopyButton { summary.checksum }
        let checksumRow = FormRowView(title: String(localized: "Checksum"), accessory: NSStackView.horizontal([checksumLabel, copyChecksum]))

        let snippet = NSTextField.text(summary.packageSnippet.trimmingCharacters(in: .newlines),
                                       font: .monospaced(.callout), lines: 0, selectable: true)
        let copySnippet = CopyButton(title: String(localized: "Copy Snippet")) { summary.packageSnippet }
        let snippetStack = NSStackView.vertical([snippet, copySnippet], spacing: 10)
        let snippetContainer = NSView()
        snippetContainer.translatesAutoresizingMaskIntoConstraints = false
        snippetContainer.addSubview(snippetStack)
        snippetStack.pinEdges(to: snippetContainer, insets: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))

        section.setRows([checksumRow, snippetContainer])
        section.footer = summary.downloadURL == nil
            ? String(localized: "Upload the zip, replace the URL in the snippet with its download link and add the target to Package.swift. Set a download URL or a publish destination in the project options to skip this step.")
            : String(localized: "Add the target to Package.swift. Private hosts need credentials in ~/.netrc for SwiftPM to download the zip.")

        return section
    }

    // MARK: - Actions

    @objc
    private func done(_ sender: Any?) {
        project.build.reset()
    }

    @objc
    private func publish(_ sender: Any?) {
        buildController.publish(project)
    }

    @objc
    private func copyDownloadURL(_ sender: Any?) {
        guard case .published(let url) = project.build.publishState else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    @objc
    private func showInFinder(_ sender: Any?) {
        guard case .succeeded(let summary) = project.build.phase else { return }

        NSWorkspace.shared.activateFileViewerSelecting([summary.plan.xcframeworkURL])
    }

    @objc
    private func revealFile(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else { return }

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    @objc
    private func openPrivacyDocumentation(_ sender: Any?) {
        NSWorkspace.shared.open(Self.privacyManifestURL)
    }

}
