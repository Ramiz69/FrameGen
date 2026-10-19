//
//  AppKit+Helpers.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

enum Metrics {
    static let margin: CGFloat = 20
    static let spacing: CGFloat = 8
    static let groupSpacing: CGFloat = 20
    static let cornerRadius: CGFloat = 10
    static let contentWidth: CGFloat = 560
}

extension NSTextField {

    static func text(_ string: String = "",
                     font: NSFont = .systemFont(ofSize: NSFont.systemFontSize),
                     color: NSColor = .labelColor,
                     lines: Int = 1,
                     selectable: Bool = false) -> NSTextField {
        let label = lines == 1 ? NSTextField(labelWithString: string) : NSTextField(wrappingLabelWithString: string)
        label.font = font
        label.textColor = color
        label.maximumNumberOfLines = lines
        label.isSelectable = selectable
        label.lineBreakMode = lines == 1 ? .byTruncatingTail : .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }

}

extension NSFont {

    static func preferred(_ style: NSFont.TextStyle, weight: NSFont.Weight? = nil) -> NSFont {
        let font = NSFont.preferredFont(forTextStyle: style)
        guard let weight else { return font }

        return .systemFont(ofSize: font.pointSize, weight: weight)
    }

    static func monospaced(_ style: NSFont.TextStyle = .body) -> NSFont {
        .monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: style).pointSize, weight: .regular)
    }

}

extension NSImageView {

    static func symbol(_ name: String,
                       pointSize: CGFloat,
                       weight: NSFont.Weight = .regular,
                       color: NSColor? = nil,
                       accessibilityDescription: String? = nil) -> NSImageView {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
        let view = NSImageView(image: image ?? NSImage())
        view.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        view.contentTintColor = color
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }

}

extension NSButton {

    static func push(_ title: String, symbol: String? = nil, target: AnyObject?, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        if let symbol {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            button.imagePosition = .imageLeading
        }
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }

}

extension NSStackView {

    static func vertical(_ views: [NSView], spacing: CGFloat = Metrics.spacing, alignment: NSLayoutConstraint.Attribute = .leading) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.alignment = alignment
        stack.translatesAutoresizingMaskIntoConstraints = false

        return stack
    }

    static func horizontal(_ views: [NSView], spacing: CGFloat = Metrics.spacing, alignment: NSLayoutConstraint.Attribute = .centerY) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = spacing
        stack.alignment = alignment
        stack.translatesAutoresizingMaskIntoConstraints = false

        return stack
    }

}

extension NSStackView {
    
    /// Vertical stacks don't stretch their views across, so the width is pinned explicitly.
    func addFullWidthArrangedSubview(_ view: NSView) {
        addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
    
}

extension NSView {

    func pinEdges(to view: NSView, insets: NSEdgeInsets = NSEdgeInsetsZero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
                                     view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: insets.right),
                                     topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
                                     view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom)])
    }

    /// A flexible view that pushes its stack-view neighbours apart.
    static func spacer() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.init(1), for: .horizontal)
        view.setContentHuggingPriority(.init(1), for: .vertical)

        return view
    }

}

extension NSViewController {

    /// Replaces the only child view controller, filling the given container.
    func setChild(_ child: NSViewController?, in container: NSView) {
        children.forEach { existing in
            existing.view.removeFromSuperview()
            existing.removeFromParent()
        }
        guard let child else { return }

        addChild(child)
        container.addSubview(child.view)
        child.view.pinEdges(to: container)
    }

}

enum Formatters {

    static func duration(_ interval: TimeInterval) -> String {
        Duration.seconds(max(interval, .zero)).formatted(.time(pattern: .minuteSecond))
    }

    static func fileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Shortens paths inside the home folder to `~/…`.
    static func path(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }

}

extension NSWorkspace {

    /// Selects the item in Finder, or opens its closest existing parent folder.
    func reveal(_ url: URL) {
        var candidate = url
        while !FileManager.default.fileExists(atPath: candidate.path), candidate.pathComponents.count > 1 {
            candidate.deleteLastPathComponent()
        }
        if candidate == url {
            activateFileViewerSelecting([url])
        } else {
            open(candidate)
        }
    }

}
