//
//  AppBuilder.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Cocoa

struct AppBuilder {
    
    static func createMainModule(frame: NSRect) -> NSViewController {
        let presenter = MainPresenter()
        let controller = MainViewController(frame: frame, presenter: presenter)
        presenter.view = controller
        
        return controller
    }
    
    static func createOptionsModule(path: String) -> NSViewController {
        let presenter = OptionsPresenter(shellManager: ShellManager(),
                                         settingsManager: SettingsManager.shared,
                                         path: path)
        let controller = OptionsViewController(presenter: presenter)
        presenter.view = controller
        
        return controller
    }
    
    static func createSettingsModule() -> NSViewController {
        let presenter = SettingsPresenter(settingsManager: SettingsManager.shared)
        let controller = SettingsViewController(presenter: presenter)
        presenter.view = controller
        
        return controller
    }
    
}
