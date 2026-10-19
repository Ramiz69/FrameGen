//
//  CalloutView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// A tinted inline message with an optional action, used instead of modal alerts.
final class CalloutView: NSView {

    enum Style {
        case warning
        case error

        var symbol: String {
            switch self {
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.octagon.fill"
            }
        }

        var color: NSColor {
            switch self {
            case .warning:
                return .systemOrange
            case .error:
                return .systemRed
            }
        }
    }

    // MARK: - Initial methods

    init(style: Style, title: String, message: String, action: NSButton? = nil) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = Metrics.cornerRadius
        box.borderColor = style.color.withAlphaComponent(0.5)
        box.fillColor = style.color.withAlphaComponent(0.1)
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = false
        addSubview(box)
        box.pinEdges(to: self)

        let icon = NSImageView.symbol(style.symbol, pointSize: 16, color: style.color)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let titleLabel = NSTextField.text(title, font: .preferred(.body, weight: .semibold), lines: 0)
        let messageLabel = NSTextField.text(message, font: .preferred(.callout), color: .secondaryLabelColor, lines: 0, selectable: true)
        var textViews: [NSView] = [titleLabel, messageLabel]
        if let action {
            textViews.append(action)
        }
        let textStack = NSStackView.vertical(textViews, spacing: 4)
        let stack = NSStackView.horizontal([icon, textStack], spacing: 10, alignment: .top)
        box.contentView?.addSubview(stack)
        if let contentView = box.contentView {
            stack.pinEdges(to: contentView, insets: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        }
        titleLabel.preferredMaxLayoutWidth = Metrics.contentWidth - 60
        messageLabel.preferredMaxLayoutWidth = Metrics.contentWidth - 60
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
