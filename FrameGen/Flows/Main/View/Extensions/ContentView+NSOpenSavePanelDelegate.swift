//
//  ContentView+NSOpenSavePanelDelegate.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

extension ContentView: NSOpenSavePanelDelegate {
    
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        guard let xcodeProjectDirectoryURL = url.xcodeProjectDirectory else {
            return false
        }
        
        return true
    }
    
}
