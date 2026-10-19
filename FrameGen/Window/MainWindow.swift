//
//  MainWindow.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit

final class MainWindow: NSWindow {

    // MARK: - Properties

    private enum Constants {
        static let defaultSize = NSSize(width: 780, height: 620)
        static let minimumSize = NSSize(width: 620, height: 520)
        static let autosaveName = "MainWindow"
    }

    // MARK: - Initial methods

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: Constants.defaultSize),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)

        title = "FrameGen"
        toolbarStyle = .unified
        contentMinSize = Constants.minimumSize
        collectionBehavior.insert(.fullScreenPrimary)
        isReleasedWhenClosed = false
    }
    
    // MARK: - Public methods
    
    /// Installing a content view controller resizes the window to the controller's view,
    /// so the default size and the saved frame are applied afterwards.
    func restoreFrame() {
        setContentSize(Constants.defaultSize)
        center()
        setFrameAutosaveName(Constants.autosaveName)
    }

}
