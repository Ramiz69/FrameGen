//
//  AppDelegate.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 08.04.2023.
//

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var windowController: NSWindowController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        windowController = MainWindowController()
        windowController.showWindow(self)
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
