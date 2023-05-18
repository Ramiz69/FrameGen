//
//  OptionsPresenter.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

protocol OptionsPresenterOutputProtocol: AnyObject {
    func makeDataFromProject()
    func cancelAllScripts()
    func runScripts(_ scripts: [Script])
    func setScheme(_ scheme: String)
    func setConfiguration(_ configuration: String)
}

protocol OptionsPresenterInputProtocol {
    var view: OptionsViewInputProtocol? { get }
    var shellManager: ShellManagerProtocol { get }
    var settingsManager: SettingsManagerProtocol { get }
    var path: String { get }
    var command: Command { get }
}

final class OptionsPresenter: OptionsPresenterInputProtocol {
    
    var view: OptionsViewInputProtocol?
    let shellManager: ShellManagerProtocol
    let settingsManager: SettingsManagerProtocol
    let path: String
    private(set) var command = Command()
    
    required init(shellManager: ShellManagerProtocol, settingsManager: SettingsManagerProtocol, path: String) {
        self.shellManager = shellManager
        self.settingsManager = settingsManager
        self.path = path
    }
    
}
