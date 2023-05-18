//
//  OptionsConfigurationView+NSComboBoxDelegate.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 23.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

extension OptionsConfigurationView: NSComboBoxDelegate {
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let box = notification.object as? NSComboBox else { return }
        
        completionHandler?(box.indexOfSelectedItem)
    }
    
}
