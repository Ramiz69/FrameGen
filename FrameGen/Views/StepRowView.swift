//
//  StepRowView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// One pipeline step: a status indicator, the step title and its duration.
final class StepRowView: NSView {

    // MARK: - Properties

    private let statusContainer = NSView()
    private let titleLabel = NSTextField.text()
    private let durationLabel = NSTextField.text(font: .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                                                 color: .secondaryLabelColor)
    private var shownStatus: BuildStep.Status?

    // MARK: - Initial methods

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([statusContainer.widthAnchor.constraint(equalToConstant: 20),
                                     statusContainer.heightAnchor.constraint(equalToConstant: 20)])
        let stack = NSStackView.horizontal([statusContainer, titleLabel, .spacer(), durationLabel], spacing: 10)
        addSubview(stack)
        stack.pinEdges(to: self, insets: NSEdgeInsets(top: 9, left: 12, bottom: 9, right: 12))
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func configure(with step: BuildStep, now: Date = .now) {
        titleLabel.stringValue = step.title
        switch step.status {
        case .pending:
            durationLabel.stringValue = ""
            titleLabel.textColor = .secondaryLabelColor
        case .running(let since):
            durationLabel.stringValue = Formatters.duration(now.timeIntervalSince(since))
            titleLabel.textColor = .labelColor
        case .succeeded(let duration):
            durationLabel.stringValue = Formatters.duration(duration)
            titleLabel.textColor = .labelColor
        case .failed:
            durationLabel.stringValue = ""
            titleLabel.textColor = .labelColor
        }
        setAccessibilityLabel("\(step.title), \(Self.accessibilityStatus(step.status))")

        // Recreating the indicator on every tick would restart the spinner animation.
        guard shownStatus.map({ Self.sameKind($0, step.status) }) != true else { return }

        shownStatus = step.status
        statusContainer.subviews.forEach { $0.removeFromSuperview() }
        let indicator: NSView
        switch step.status {
        case .pending:
            indicator = NSImageView.symbol("circle.dashed", pointSize: 15, color: .tertiaryLabelColor)
        case .running:
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.startAnimation(nil)
            indicator = spinner
        case .succeeded:
            indicator = NSImageView.symbol("checkmark.circle.fill", pointSize: 15, color: .systemGreen)
        case .failed:
            indicator = NSImageView.symbol("xmark.octagon.fill", pointSize: 15, color: .systemRed)
        }
        statusContainer.addSubview(indicator)
        NSLayoutConstraint.activate([indicator.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
                                     indicator.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor)])
    }

    // MARK: - Private methods

    private static func sameKind(_ lhs: BuildStep.Status, _ rhs: BuildStep.Status) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending), (.running, .running), (.succeeded, .succeeded), (.failed, .failed):
            return true
        default:
            return false
        }
    }

    private static func accessibilityStatus(_ status: BuildStep.Status) -> String {
        switch status {
        case .pending:
            return "waiting"
        case .running:
            return "in progress"
        case .succeeded:
            return "done"
        case .failed:
            return "failed"
        }
    }

}
