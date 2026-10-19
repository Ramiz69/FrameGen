//
//  StatusHeaderView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// A large status symbol with a title and a secondary line, used at the top of build screens.
final class StatusHeaderView: NSView {

    // MARK: - Properties

    private let iconContainer = NSView()
    let titleLabel = NSTextField.text(font: .preferred(.title2, weight: .semibold), lines: 2)
    let subtitleLabel = NSTextField.text(font: .preferred(.body), color: .secondaryLabelColor, lines: 3)

    // MARK: - Initial methods

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([iconContainer.widthAnchor.constraint(equalToConstant: 44),
                                     iconContainer.heightAnchor.constraint(equalToConstant: 44)])
        let textStack = NSStackView.vertical([titleLabel, subtitleLabel], spacing: 4)
        let stack = NSStackView.horizontal([iconContainer, textStack], spacing: 14, alignment: .centerY)
        addSubview(stack)
        stack.pinEdges(to: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func setSymbol(_ name: String, color: NSColor, accessibilityDescription: String) {
        setIcon(NSImageView.symbol(name, pointSize: 34, weight: .medium, color: color,
                                   accessibilityDescription: accessibilityDescription))
    }

    func setSpinner() {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimation(nil)
        spinner.setAccessibilityLabel(String(localized: "Building"))
        setIcon(spinner)
    }

    // MARK: - Private methods

    private func setIcon(_ view: NSView) {
        iconContainer.subviews.forEach { $0.removeFromSuperview() }
        iconContainer.addSubview(view)
        NSLayoutConstraint.activate([view.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
                                     view.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)])
    }

}
