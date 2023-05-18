//
//  SettingsContentView+NSComboBoxDelegate.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 26.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

extension SettingsContentView: NSComboBoxDelegate {
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard
            let box = notification.object as? NSComboBox,
            let locationType = LocationType(rawValue: box.indexOfSelectedItem)
        else {
            return
        }
        
        self.locationType = locationType
    }
    
}
