//
//  BuildProgressViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Live progress of a build: the step list, the current xcodebuild action and the log.
final class BuildProgressViewController: NSViewController {

    // MARK: - Properties

    private let project: Project
    private var observation: ObservationLoop?
    private var clockTask: Task<Void, Never>?

    private let contentView = ScrollingContentView()
    private let header = StatusHeaderView()
    private let activityLabel = NSTextField.text(font: .monospaced(.callout), color: .secondaryLabelColor)
    private let stepsSection = FormSectionView(title: nil)
    private var stepRows: [StepRowView] = []
    private let logDisclosure = NSButton()
    private let logView = LogView()
    private let logHeightConstraint: NSLayoutConstraint

    // MARK: - Initial methods

    init(project: Project) {
        self.project = project
        logHeightConstraint = logView.heightAnchor.constraint(equalToConstant: 240)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        clockTask?.cancel()
    }

    // MARK: - Life cycle

    override func loadView() {
        header.setSpinner()
        activityLabel.lineBreakMode = .byTruncatingMiddle
        activityLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        stepRows = project.build.steps.map { _ in StepRowView() }
        stepsSection.setRows(stepRows)

        logDisclosure.bezelStyle = .disclosure
        logDisclosure.setButtonType(.pushOnPushOff)
        logDisclosure.title = ""
        logDisclosure.target = self
        logDisclosure.action = #selector(toggleLog(_:))
        logDisclosure.setAccessibilityLabel("Show build log")
        let logTitle = NSTextField.text("Build Log", font: .preferred(.headline))
        let copyLog = CopyButton(title: "Copy Log") { [weak self] in
            self?.project.build.log.joined(separator: "\n") ?? ""
        }
        copyLog.controlSize = .small
        let logHeader = NSStackView.horizontal([logDisclosure, logTitle, .spacer(), copyLog], spacing: 4)
        logHeightConstraint.isActive = true
        logView.isHidden = true

        let stopButton = NSButton.push("Stop", symbol: "stop.fill", target: nil, action: #selector(MainWindowController.stopBuild(_:)))
        stopButton.controlSize = .large
        stopButton.keyEquivalent = "\u{1b}"
        stopButton.toolTip = "Stop the build (⌘.)"

        [header, activityLabel, stepsSection, logHeader, logView].forEach(contentView.stackView.addFullWidthArrangedSubview)
        contentView.stackView.setCustomSpacing(Metrics.spacing, after: header)
        contentView.stackView.setCustomSpacing(Metrics.spacing, after: logHeader)
        contentView.setBottomBar(leading: [], trailing: [stopButton])
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        observation = ObservationLoop { [weak self] in
            self?.update()
        }
        // Durations of running steps tick every second even when xcodebuild is quiet.
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.updateClock()
            }
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        clockTask?.cancel()
        observation?.cancel()
    }

    // MARK: - Private methods

    private func update() {
        let build = project.build
        let platformCount = build.steps.count - 2
        header.titleLabel.stringValue = "Building \(project.scheme ?? project.name)"
        activityLabel.stringValue = build.activity
        if !logView.isHidden {
            logView.update(lines: build.log)
        }
        updateClock()
        header.subtitleLabel.stringValue = "\(project.configuration ?? "") · \(platformCount) platform\(platformCount == 1 ? "" : "s")"
    }

    private func updateClock() {
        let build = project.build
        for (row, step) in zip(stepRows, build.steps) {
            row.configure(with: step)
        }
        view.window?.subtitle = "Building… \(Formatters.duration(build.duration))"
    }

    // MARK: - Actions

    @objc
    private func toggleLog(_ sender: NSButton) {
        logView.isHidden = sender.state == .off
        sender.setAccessibilityLabel(logView.isHidden ? "Show build log" : "Hide build log")
        if !logView.isHidden {
            logView.update(lines: project.build.log)
        }
    }

}
