//
//  DropTargetView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 26.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Accepts a dragged project or folder anywhere in the window and outlines the window while dragging.
final class DropTargetView: NSView {

    // MARK: - Properties

    /// Returns whether the drop can be accepted right now, e.g. not while building.
    var canAcceptDrop: () -> Bool = { true }
    var onDrop: (URL) -> Void = { _ in }

    private var isTargeted = false {
        didSet { updateHighlight() }
    }
    
    // MARK: - Initial methods
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateHighlight()
    }
    
    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canAcceptDrop(), fileURL(from: sender) != nil else { return [] }

        isTargeted = true

        return .link
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isTargeted = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        isTargeted = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isTargeted = false
        guard canAcceptDrop(), let url = fileURL(from: sender) else { return false }

        onDrop(url)

        return true
    }

    // MARK: - Private methods
    
    /// A layer border is composited above sublayers, so it outlines the window over any content.
    private func updateHighlight() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.borderWidth = isTargeted ? 3 : 0
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = isTargeted ? NSColor.controlAccentColor.withAlphaComponent(0.06).cgColor : nil
        }
    }

    private func fileURL(from info: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]

        return (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL])?.first
    }

}
