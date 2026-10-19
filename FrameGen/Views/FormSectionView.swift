//
//  FormSectionView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// A titled, rounded group of rows separated by hairlines, in the style of System Settings.
final class FormSectionView: NSView {

    // MARK: - Properties

    private let rowsStack = NSStackView.vertical([], spacing: .zero, alignment: .leading)
    private let footerLabel = NSTextField.text(font: .preferred(.footnote), color: .secondaryLabelColor, lines: 0)

    var footer: String? {
        didSet {
            footerLabel.stringValue = footer ?? ""
            footerLabel.isHidden = footer?.isEmpty ?? true
        }
    }

    // MARK: - Initial methods

    init(title: String?, rows: [NSView] = []) {
        super.init(frame: .zero)

        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = Metrics.cornerRadius
        box.borderColor = .separatorColor
        box.fillColor = .quinarySystemFill
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = false
        if let contentView = box.contentView {
            contentView.addSubview(rowsStack)
            rowsStack.pinEdges(to: contentView)
        }

        var views: [NSView] = []
        if let title {
            let titleLabel = NSTextField.text(title, font: .preferred(.headline))
            titleLabel.setAccessibilityRole(.staticText)
            views.append(titleLabel)
        }
        views += [box, footerLabel]
        footerLabel.isHidden = true

        let stack = NSStackView.vertical(views, spacing: Metrics.spacing, alignment: .leading)
        addSubview(stack)
        stack.pinEdges(to: self)
        box.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        footerLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        translatesAutoresizingMaskIntoConstraints = false

        setRows(rows)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func setRows(_ rows: [NSView]) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                let inset = NSView()
                inset.translatesAutoresizingMaskIntoConstraints = false
                inset.addSubview(separator)
                separator.pinEdges(to: inset, insets: NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12))
                rowsStack.addFullWidthArrangedSubview(inset)
            }
            rowsStack.addFullWidthArrangedSubview(row)
        }
    }

}

/// A form row: optional icon, title with an optional subtitle, and a trailing accessory.
final class FormRowView: NSView {

    // MARK: - Properties

    let titleLabel: NSTextField
    let subtitleLabel: NSTextField

    // MARK: - Initial methods

    init(title: String, subtitle: String? = nil, symbol: String? = nil, accessory: NSView? = nil) {
        titleLabel = .text(title)
        subtitleLabel = .text(subtitle ?? "", font: .preferred(.subheadline), color: .secondaryLabelColor)
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.isHidden = subtitle == nil
        subtitleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textStack = NSStackView.vertical([titleLabel, subtitleLabel], spacing: 2)
        var views: [NSView] = []
        if let symbol {
            let icon = NSImageView.symbol(symbol, pointSize: 17, color: .controlAccentColor)
            icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
            views.append(icon)
        }
        views += [textStack, .spacer()]
        if let accessory {
            accessory.setContentCompressionResistancePriority(.required, for: .horizontal)
            views.append(accessory)
        }

        let stack = NSStackView.horizontal(views, spacing: 10)
        addSubview(stack)
        stack.pinEdges(to: self, insets: NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
