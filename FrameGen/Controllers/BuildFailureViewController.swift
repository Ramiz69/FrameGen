//
//  BuildFailureViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Explains which step failed, highlights the compiler errors and keeps the full log at hand.
final class BuildFailureViewController: NSViewController {

    // MARK: - Properties

    private let project: Project
    private let logView = LogView()

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
        guard case .failed(let failure) = project.build.phase else { return }

        let header = StatusHeaderView()
        header.setSymbol("xmark.octagon.fill", color: .systemRed, accessibilityDescription: "Failed")
        header.titleLabel.stringValue = failure.title
        header.subtitleLabel.stringValue = failure.reason
        contentView.stackView.addFullWidthArrangedSubview(header)

        let stepsSection = FormSectionView(title: nil)
        stepsSection.setRows(project.build.steps.map { step in
            let row = StepRowView()
            row.configure(with: step)

            return row
        })
        contentView.stackView.addFullWidthArrangedSubview(stepsSection)

        if !failure.highlights.isEmpty {
            let section = FormSectionView(title: "Errors")
            let text = NSTextField.text(failure.highlights.joined(separator: "\n"),
                                        font: .monospaced(.callout), color: .labelColor, lines: 0, selectable: true)
            text.preferredMaxLayoutWidth = Metrics.contentWidth - 24
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(text)
            text.pinEdges(to: container, insets: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
            section.setRows([container])
            contentView.stackView.addFullWidthArrangedSubview(section)
        }

        let logTitle = NSTextField.text("Build Log", font: .preferred(.headline))
        let copyLog = CopyButton(title: "Copy Log") { [weak self] in
            self?.project.build.log.joined(separator: "\n") ?? ""
        }
        copyLog.controlSize = .small
        logView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        logView.update(lines: project.build.log)
        contentView.stackView.addFullWidthArrangedSubview(NSStackView.horizontal([logTitle, .spacer(), copyLog]))
        contentView.stackView.addFullWidthArrangedSubview(logView)

        let backButton = NSButton.push("Edit Options", target: self, action: #selector(back(_:)))
        backButton.controlSize = .large
        backButton.keyEquivalent = "\u{1b}"
        let retryButton = NSButton.push("Try Again", symbol: "arrow.clockwise", target: nil,
                                        action: #selector(MainWindowController.buildXCFramework(_:)))
        retryButton.controlSize = .large
        retryButton.keyEquivalent = "\r"
        contentView.setBottomBar(leading: [backButton], trailing: [retryButton])
    }

    // MARK: - Actions

    @objc
    private func back(_ sender: Any?) {
        project.build.reset()
    }

}
