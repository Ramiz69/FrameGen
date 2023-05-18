//
//  SettingsPresenter+SettingsPresenterOutputProtocol.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 26.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

extension SettingsPresenter: SettingsPresenterOutputProtocol {
    
    func fileSelected(_ path: String) {
        settingsManager.setNewPath(path)
    }
    
}
