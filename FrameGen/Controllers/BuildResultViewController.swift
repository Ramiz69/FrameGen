//
//  BuildResultViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Shows what was built and everything needed to publish it as a SwiftPM binary target.
final class BuildResultViewController: NSViewController {

    // MARK: - Properties

    private let project: Project

    private static let privacyManifestURL = URL(string: "https://developer.apple.com/documentation/bundleresources/privacy-manifest-files")!

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
        let contentView = ScrollingContentView()
        view = contentView
        guard case .succeeded(let summary) = project.build.phase else { return }

        let header = StatusHeaderView()
        header.setSymbol("checkmark.seal.fill", color: .systemGreen, accessibilityDescription: "Succeeded")
        header.titleLabel.stringValue = "\(summary.plan.xcframeworkURL.lastPathComponent) is ready"
        let platformCount = summary.plan.slices.count
        header.subtitleLabel.stringValue = "Built in \(Formatters.duration(project.build.duration)) · "
            + "\(platformCount) platform\(platformCount == 1 ? "" : "s") · \(Formatters.fileSize(summary.zipSize)) zipped"
        contentView.stackView.addFullWidthArrangedSubview(header)

        if !summary.librariesWithoutPrivacyManifest.isEmpty {
            let learnMore = NSButton.push("Learn About Privacy Manifests", target: self, action: #selector(openPrivacyDocumentation(_:)))
            learnMore.bezelStyle = .inline
            contentView.stackView.addFullWidthArrangedSubview(
                CalloutView(style: .warning,
                            title: "No privacy manifest",
                            message: "PrivacyInfo.xcprivacy is missing in \(summary.librariesWithoutPrivacyManifest.joined(separator: ", ")). "
                                + "Apple requires privacy manifests in commonly used third-party SDKs.",
                            action: learnMore))
        }

        contentView.stackView.addFullWidthArrangedSubview(makeFilesSection(summary))
        contentView.stackView.addFullWidthArrangedSubview(makePackageSection(summary))

        let doneButton = NSButton.push("Done", target: self, action: #selector(done(_:)))
        doneButton.controlSize = .large
        doneButton.keyEquivalent = "\u{1b}"
        let buildAgain = NSButton.push("Build Again", target: nil, action: #selector(MainWindowController.buildXCFramework(_:)))
        buildAgain.controlSize = .large
        let showInFinder = NSButton.push("Show in Finder", symbol: "folder", target: self, action: #selector(showInFinder(_:)))
        showInFinder.controlSize = .large
        showInFinder.keyEquivalent = "\r"
        contentView.setBottomBar(leading: [doneButton], trailing: [buildAgain, showInFinder])
    }

    // MARK: - Private methods

    private func makeFilesSection(_ summary: XCFrameworkBuilder.Summary) -> NSView {
        let section = FormSectionView(title: "Files")
        let rows = [summary.plan.xcframeworkURL, summary.plan.zipURL, summary.plan.snippetURL].map { url in
            let reveal = NSButton(image: NSImage(systemSymbolName: "arrow.forward.circle.fill", accessibilityDescription: "Show in Finder")!,
                                  target: self,
                                  action: #selector(revealFile(_:)))
            reveal.isBordered = false
            reveal.contentTintColor = .secondaryLabelColor
            reveal.toolTip = "Show in Finder"
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
        let section = FormSectionView(title: "Swift Package Manager")

        let checksumLabel = NSTextField.text(summary.checksum, font: .monospaced(.callout), selectable: true)
        checksumLabel.lineBreakMode = .byTruncatingMiddle
        checksumLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let copyChecksum = CopyButton { summary.checksum }
        let checksumRow = FormRowView(title: "Checksum", accessory: NSStackView.horizontal([checksumLabel, copyChecksum]))

        let snippet = NSTextField.text(summary.packageSnippet.trimmingCharacters(in: .newlines),
                                       font: .monospaced(.callout), lines: 0, selectable: true)
        let copySnippet = CopyButton(title: "Copy Snippet") { summary.packageSnippet }
        let snippetStack = NSStackView.vertical([snippet, copySnippet], spacing: 10)
        let snippetContainer = NSView()
        snippetContainer.translatesAutoresizingMaskIntoConstraints = false
        snippetContainer.addSubview(snippetStack)
        snippetStack.pinEdges(to: snippetContainer, insets: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))

        section.setRows([checksumRow, snippetContainer])
        section.footer = "Upload the zip, replace the URL in the snippet with its download link and add the target to Package.swift."

        return section
    }

    // MARK: - Actions

    @objc
    private func done(_ sender: Any?) {
        project.build.reset()
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
