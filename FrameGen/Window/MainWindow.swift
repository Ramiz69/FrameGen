//
//  MainWindow.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Cocoa

final class MainWindow: NSWindow {
    
    // MARK: - Properties
    
    private var observation: NSKeyValueObservation?
    
    private enum Constants {
        static let appName = "FrameGen"
        static let defaultSize = NSRect(x: .zero, y: .zero, width: 300, height: 500)
    }
    
    // MARK: - Initial methods
    
    convenience init() {
        self.init(contentRect: Constants.defaultSize,
                   styleMask: [.miniaturizable, .resizable, .titled, .closable],
                   backing: .buffered,
                   defer: false,
                   screen: .main)
        
        title = Constants.appName
        delegate = self
        contentViewController = AppBuilder.createMainModule(frame: Constants.defaultSize)
        observation = NSApp.observe(\.effectiveAppearance) { app, _ in
            app.effectiveAppearance.performAsCurrentDrawingAppearance {
                self.appearance = app.effectiveAppearance
            }
        }
    }
    
}

extension MainWindow: NSWindowDelegate {
    
}
