//
//  MainMenu.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//

import Cocoa

final class MainMenu: NSMenu {
    
    // MARK: - Properties
    
    private lazy var applicationName = ProcessInfo.processInfo.processName
    
    // MARK: - Initial methods
    
    override init(title: String) {
        super.init(title: title)
        
        configureMenu()
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private methods
    
    private func configureMenu() {
        let mainMenu = NSMenuItem()
        mainMenu.submenu = NSMenu(title: "menuItem")
        let hideOtherItem = NSMenuItem(title: "Hide Others",
                                       action: #selector(NSApplication.hideOtherApplications(_:)),
                                       keyEquivalent: "h")
        hideOtherItem.keyEquivalentModifierMask = .option
        let submenuItems = [NSMenuItem(title: "About \(applicationName)",
                                       action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                                       keyEquivalent: ""),
                            .separator(),
                            NSMenuItem(title: "Hide \(applicationName)",
                                       action: #selector(NSApplication.hide(_:)),
                                       keyEquivalent: "h"),
                            hideOtherItem,
                            NSMenuItem(title: "Show all",
                                       action: #selector(NSApplication.unhideAllApplications(_:)),
                                       keyEquivalent: ""),
                            .separator(),
                            NSMenuItem(title: "Quit \(applicationName)",
                                       action: #selector(NSApplication.terminate(_:)),
                                       keyEquivalent: "q")]
        mainMenu.submenu?.items = submenuItems
        
        let windowMenu = NSMenuItem()
        windowMenu.submenu = NSMenu(title: "Window")
        windowMenu.submenu?.items = [NSMenuItem(title: "Minmize",
                                                action: #selector(NSWindow.miniaturize(_:)),
                                                keyEquivalent: "m"),
                                     NSMenuItem(title: "Zoom",
                                                action: #selector(NSWindow.performZoom(_:)),
                                                keyEquivalent: "")]
        
        items = [mainMenu, windowMenu]
    }
    
}
