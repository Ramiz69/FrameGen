//
//  RecentProjectCellView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

final class RecentProjectCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("RecentProjectCell")

    // MARK: - Properties

    private let iconView = NSImageView()
    private let nameLabel = NSTextField.text(font: .preferred(.body, weight: .semibold))
    private let pathLabel = NSTextField.text(font: .preferred(.subheadline), color: .secondaryLabelColor)

    // MARK: - Initial methods

    init() {
        super.init(frame: .zero)

        identifier = Self.identifier
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        NSLayoutConstraint.activate([iconView.widthAnchor.constraint(equalToConstant: 32),
                                     iconView.heightAnchor.constraint(equalToConstant: 32)])
        pathLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textStack = NSStackView.vertical([nameLabel, pathLabel], spacing: 1)
        let stack = NSStackView.horizontal([iconView, textStack], spacing: 10)
        addSubview(stack)
        stack.pinEdges(to: self, insets: NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6))
        textField = nameLabel
        imageView = iconView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func configure(with url: URL) {
        iconView.image = NSWorkspace.shared.icon(forFile: url.path)
        nameLabel.stringValue = url.deletingPathExtension().lastPathComponent
        pathLabel.stringValue = Formatters.path(url.deletingLastPathComponent())
        toolTip = url.path
        setAccessibilityLabel(String(localized: "\(nameLabel.stringValue), \(pathLabel.stringValue)"))
    }

}
