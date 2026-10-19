//
//  LogView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// A read-only, selectable monospaced text view that appends lines incrementally
/// and keeps following the end unless the user scrolled up.
final class LogView: NSView {

    // MARK: - Properties

    private let scrollView = NSTextView.scrollableTextView()
    private var textView: NSTextView {
        scrollView.documentView as! NSTextView
    }
    private var renderedLineCount = 0

    var text: String {
        textView.string
    }

    // MARK: - Initial methods

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .monospaced(.callout)
        textView.textColor = .labelColor
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.setAccessibilityLabel("Build log")
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 8
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(scrollView)
        scrollView.pinEdges(to: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    // MARK: - Public methods

    /// Appends only the lines added since the last call; a shorter array means a new build started.
    func update(lines: [String]) {
        if lines.count < renderedLineCount {
            textView.string = ""
            renderedLineCount = 0
        }
        guard lines.count > renderedLineCount, let storage = textView.textStorage else { return }

        let isFollowingEnd = isScrolledToEnd
        let newText = lines[renderedLineCount...].joined(separator: "\n") + "\n"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospaced(.callout),
                                                         .foregroundColor: NSColor.labelColor]
        storage.append(NSAttributedString(string: newText, attributes: attributes))
        renderedLineCount = lines.count
        if isFollowingEnd {
            textView.scrollToEndOfDocument(nil)
        }
    }

    // MARK: - Private methods

    private var isScrolledToEnd: Bool {
        let visible = scrollView.contentView.documentVisibleRect

        return visible.maxY >= textView.bounds.maxY - 40
    }

}
