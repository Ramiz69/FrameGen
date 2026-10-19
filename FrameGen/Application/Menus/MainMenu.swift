//
//  MainMenu.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit
import FrameGenKit

/// Builds the standard Mac menu bar plus the Product menu. Items target the responder chain,
/// so the main window controller handles and validates the project commands.
final class MainMenu: NSObject {
    
    // MARK: - Properties
    
    let menu = NSMenu(title: "Main Menu")
    private let applicationName = ProcessInfo.processInfo.processName
    private let recentProjectsMenu = NSMenu(title: String(localized: "Open Recent"))
    
    // MARK: - Initial methods
    
    override init() {
        super.init()
        
        recentProjectsMenu.delegate = self
        menu.items = [submenu(applicationName, items: applicationItems()),
                      submenu(String(localized: "File"), items: fileItems()),
                      submenu(String(localized: "Edit"), items: editItems()),
                      submenu(String(localized: "Product"), items: productItems()),
                      windowMenu(),
                      helpMenu()]
    }
    
    // MARK: - Private methods

    private func applicationItems() -> [NSMenuItem] {
        let services = NSMenuItem(title: String(localized: "Services"), action: nil, keyEquivalent: "")
        services.submenu = NSMenu(title: String(localized: "Services"))
        NSApp.servicesMenu = services.submenu

        return [item(String(localized: "About \(applicationName)"), #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
                .separator(),
                item(String(localized: "Settings…"), #selector(AppDelegate.showSettings(_:)), key: ","),
                .separator(),
                services,
                .separator(),
                item(String(localized: "Hide \(applicationName)"), #selector(NSApplication.hide(_:)), key: "h"),
                item(String(localized: "Hide Others"), #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option]),
                item(String(localized: "Show All"), #selector(NSApplication.unhideAllApplications(_:))),
                .separator(),
                item(String(localized: "Quit \(applicationName)"), #selector(NSApplication.terminate(_:)), key: "q")]
    }

    private func fileItems() -> [NSMenuItem] {
        let openRecent = NSMenuItem(title: String(localized: "Open Recent"), action: nil, keyEquivalent: "")
        openRecent.submenu = recentProjectsMenu

        return [item(String(localized: "Open Project…"), #selector(MainWindowController.openDocument(_:)), key: "o"),
                openRecent,
                .separator(),
                item(String(localized: "Close Project"), #selector(MainWindowController.closeProject(_:)), key: "w", modifiers: [.command, .shift]),
                item(String(localized: "Close Window"), #selector(NSWindow.performClose(_:)), key: "w")]
    }

    private func editItems() -> [NSMenuItem] {
        [item(String(localized: "Undo"), Selector(("undo:")), key: "z"),
         item(String(localized: "Redo"), Selector(("redo:")), key: "z", modifiers: [.command, .shift]),
         .separator(),
         item(String(localized: "Cut"), #selector(NSText.cut(_:)), key: "x"),
         item(String(localized: "Copy"), #selector(NSText.copy(_:)), key: "c"),
         item(String(localized: "Paste"), #selector(NSText.paste(_:)), key: "v"),
         item(String(localized: "Select All"), #selector(NSText.selectAll(_:)), key: "a")]
    }

    private func productItems() -> [NSMenuItem] {
        [item(String(localized: "Build XCFramework"), #selector(MainWindowController.buildXCFramework(_:)), key: "b"),
         item(String(localized: "Stop"), #selector(MainWindowController.stopBuild(_:)), key: "."),
         .separator(),
         item(String(localized: "Publish"), #selector(MainWindowController.publishXCFramework(_:)), key: "u"),
         item(String(localized: "Copy Build Command"), #selector(MainWindowController.copyBuildCommand(_:)), key: "c", modifiers: [.command, .option]),
         .separator(),
         item(String(localized: "Show Output in Finder"), #selector(MainWindowController.showOutputInFinder(_:)), key: "r", modifiers: [.command, .shift])]
    }

    private func windowMenu() -> NSMenuItem {
        let menuItem = submenu(String(localized: "Window"), items: [item(String(localized: "Minimize"), #selector(NSWindow.performMiniaturize(_:)), key: "m"),
                                                 item(String(localized: "Zoom"), #selector(NSWindow.performZoom(_:))),
                                                 .separator(),
                                                 item(String(localized: "Bring All to Front"), #selector(NSApplication.arrangeInFront(_:)))])
        NSApp.windowsMenu = menuItem.submenu

        return menuItem
    }

    private func helpMenu() -> NSMenuItem {
        let menuItem = submenu(String(localized: "Help"), items: [])
        NSApp.helpMenu = menuItem.submenu

        return menuItem
    }

    private func submenu(_ title: String, items: [NSMenuItem]) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        menu.items = items
        menuItem.submenu = menu

        return menuItem
    }

    private func item(_ title: String,
                      _ action: Selector,
                      key: String = "",
                      modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.keyEquivalentModifierMask = modifiers

        return menuItem
    }

}

// MARK: - NSMenuDelegate

extension MainMenu: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === recentProjectsMenu else { return }

        let recentProjects = Preferences.recentProjects
        menu.items = recentProjects.map(\.url).map { url in
            let menuItem = NSMenuItem(title: url.deletingPathExtension().lastPathComponent,
                                      action: #selector(MainWindowController.openRecentProject(_:)),
                                      keyEquivalent: "")
            menuItem.representedObject = url
            menuItem.toolTip = Formatters.path(url)
            menuItem.image = NSWorkspace.shared.icon(forFile: url.path)
            menuItem.image?.size = NSSize(width: 16, height: 16)

            return menuItem
        }
        if !recentProjects.isEmpty {
            menu.addItem(.separator())
        }
        menu.addItem(item(String(localized: "Clear Menu"), #selector(MainWindowController.clearRecentProjects(_:))))
    }

}
