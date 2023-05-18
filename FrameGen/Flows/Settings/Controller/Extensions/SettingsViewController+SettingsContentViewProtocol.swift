//
//  SettingsViewController+SettingsContentViewProtocol.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 27.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

extension SettingsViewController: SettingsContentViewProtocol {
    
    func dismissView() {
        dismiss(self)
    }
    
    func fileSelected(_ path: String) {
        presenter.fileSelected(path)
    }
    
}
