//
//  SettingsPresenter.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 26.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

protocol SettingsPresenterOutputProtocol: AnyObject {
    
    func fileSelected(_ path: String)
    
}

protocol SettingsPresenterInputProtocol {
    var view: SettingsViewInputProtocol? { get }
    var settingsManager: SettingsManagerProtocol { get }
}

final class SettingsPresenter: SettingsPresenterInputProtocol {
    
    var view: SettingsViewInputProtocol?
    let settingsManager: SettingsManagerProtocol
    
    required init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
    
}
