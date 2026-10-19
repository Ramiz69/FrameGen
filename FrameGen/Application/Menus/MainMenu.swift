//
//  MainMenu.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Builds the standard Mac menu bar plus the Product menu. Items target the responder chain,
/// so the main window controller handles and validates the project commands.
final class MainMenu: NSObject {
    
    // MARK: - Properties
    
    let menu = NSMenu(title: "Main Menu")
    private let applicationName = ProcessInfo.processInfo.processName
    private let recentProjectsMenu = NSMenu(title: "Open Recent")
    
    // MARK: - Initial methods
    
    override init() {
        super.init()
        
        recentProjectsMenu.delegate = self
        menu.items = [submenu(applicationName, items: applicationItems()),
                      submenu("File", items: fileItems()),
                      submenu("Edit", items: editItems()),
                      submenu("Product", items: productItems()),
                      windowMenu(),
                      helpMenu()]
    }
    
    // MARK: - Private methods

    private func applicationItems() -> [NSMenuItem] {
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        services.submenu = NSMenu(title: "Services")
        NSApp.servicesMenu = services.submenu

        return [item("About \(applicationName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
                .separator(),
                item("Settings…", #selector(AppDelegate.showSettings(_:)), key: ","),
                .separator(),
                services,
                .separator(),
                item("Hide \(applicationName)", #selector(NSApplication.hide(_:)), key: "h"),
                item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option]),
                item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
                .separator(),
                item("Quit \(applicationName)", #selector(NSApplication.terminate(_:)), key: "q")]
    }

    private func fileItems() -> [NSMenuItem] {
        let openRecent = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        openRecent.submenu = recentProjectsMenu

        return [item("Open Project…", #selector(MainWindowController.openDocument(_:)), key: "o"),
                openRecent,
                .separator(),
                item("Close Project", #selector(MainWindowController.closeProject(_:)), key: "w", modifiers: [.command, .shift]),
                item("Close Window", #selector(NSWindow.performClose(_:)), key: "w")]
    }

    private func editItems() -> [NSMenuItem] {
        [item("Undo", Selector(("undo:")), key: "z"),
         item("Redo", Selector(("redo:")), key: "z", modifiers: [.command, .shift]),
         .separator(),
         item("Cut", #selector(NSText.cut(_:)), key: "x"),
         item("Copy", #selector(NSText.copy(_:)), key: "c"),
         item("Paste", #selector(NSText.paste(_:)), key: "v"),
         item("Select All", #selector(NSText.selectAll(_:)), key: "a")]
    }

    private func productItems() -> [NSMenuItem] {
        [item("Build XCFramework", #selector(MainWindowController.buildXCFramework(_:)), key: "b"),
         item("Stop", #selector(MainWindowController.stopBuild(_:)), key: "."),
         .separator(),
         item("Show Output in Finder", #selector(MainWindowController.showOutputInFinder(_:)), key: "r", modifiers: [.command, .shift])]
    }

    private func windowMenu() -> NSMenuItem {
        let menuItem = submenu("Window", items: [item("Minimize", #selector(NSWindow.performMiniaturize(_:)), key: "m"),
                                                 item("Zoom", #selector(NSWindow.performZoom(_:))),
                                                 .separator(),
                                                 item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))])
        NSApp.windowsMenu = menuItem.submenu

        return menuItem
    }

    private func helpMenu() -> NSMenuItem {
        let menuItem = submenu("Help", items: [])
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
        menu.items = recentProjects.map { url in
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
        menu.addItem(item("Clear Menu", #selector(MainWindowController.clearRecentProjects(_:))))
    }

}
