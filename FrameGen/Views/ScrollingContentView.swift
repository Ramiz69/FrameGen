//
//  ScrollingContentView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// A vertically scrolling, top-aligned column of content with a readable maximum width,
/// and an optional bar pinned to the bottom of the window.
final class ScrollingContentView: NSView {

    // MARK: - Properties

    let stackView = NSStackView.vertical([], spacing: Metrics.groupSpacing, alignment: .leading)
    private let scrollView = NSScrollView()
    private let barContainer = NSView()

    // MARK: - Initial methods

    init() {
        super.init(frame: .zero)

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)
        scrollView.documentView = documentView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        barContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        addSubview(barContainer)

        let preferredWidth = stackView.widthAnchor.constraint(equalToConstant: Metrics.contentWidth)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([scrollView.topAnchor.constraint(equalTo: topAnchor),
                                     scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                                     scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                                     scrollView.bottomAnchor.constraint(equalTo: barContainer.topAnchor),
                                     barContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
                                     barContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
                                     barContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
                                     documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
                                     stackView.topAnchor.constraint(equalTo: documentView.topAnchor, constant: Metrics.margin),
                                     documentView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor, constant: Metrics.margin),
                                     stackView.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
                                     stackView.leadingAnchor.constraint(greaterThanOrEqualTo: documentView.leadingAnchor, constant: Metrics.margin),
                                     preferredWidth])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    /// Pins a bar of buttons to the bottom: `leading` views on the left, `trailing` views on the right.
    func setBottomBar(leading: [NSView], trailing: [NSView]) {
        barContainer.subviews.forEach { $0.removeFromSuperview() }
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView.horizontal(leading + [.spacer()] + trailing, spacing: Metrics.spacing + 4)
        barContainer.addSubview(separator)
        barContainer.addSubview(stack)
        NSLayoutConstraint.activate([separator.topAnchor.constraint(equalTo: barContainer.topAnchor),
                                     separator.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor),
                                     separator.trailingAnchor.constraint(equalTo: barContainer.trailingAnchor),
                                     stack.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 14),
                                     stack.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor, constant: Metrics.margin),
                                     barContainer.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: Metrics.margin),
                                     barContainer.bottomAnchor.constraint(equalTo: stack.bottomAnchor, constant: 14)])
    }

}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
