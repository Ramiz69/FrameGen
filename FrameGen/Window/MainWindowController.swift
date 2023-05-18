//
//  MainWindowController.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Cocoa

final class MainWindowController: NSWindowController {
    
    // MARK: - Initial methods
    
    required init() {
        let window = MainWindow()
        super.init(window: window)
    }
    
    @available(*, unavailable)
    override init(window: NSWindow?) {
        fatalError("init(window:) has not been implemented")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life cycle
    
    override func showWindow(_ sender: Any?) {
        window?.center()
        window?.makeKeyAndOrderFront(sender)
    }
    
}
