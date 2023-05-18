//
//  OptionsPresenter+OptionsPresenterOutputProtocol.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

extension OptionsPresenter: OptionsPresenterOutputProtocol {
    
    func setScheme(_ scheme: String) {
        command.setScheme(scheme)
    }
    
    func setConfiguration(_ configuration: String) {
        command.setConfiguration(configuration)
    }
    
    func makeDataFromProject() {
        xcodeVersionCheck()
        var data: (configurations: [String], schemes: [String]) = ([], [])
        shellManager.shell(.getSchemesFromProject(path)) {
            switch $0 {
            case .success(let result):
                switch result {
                case let .output(message, log):
                    if let splitSuccess = log.splitAtFirst(delimiter: "Build Configurations:")?
                        .before
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       let configurations = splitSuccess.splitAtFirst(delimiter: "If no build configuration is specified and -scheme is not passed then \"Release\" is used.")?
                        .after
                        .components(separatedBy: "\n")
                        .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
                        data.configurations = configurations.filter { !$0.isEmpty }
                    } else {
                        data.configurations = ["Release"]
                    }
                    guard
                        let schemes = log.splitAtFirst(delimiter: "Schemes:")?
                            .before
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .components(separatedBy: "\n")
                    else {
                        DispatchQueue.main.async {
                            self.view?.updateData(data)
                        }
                        
                        return
                    }
                    
                    data.schemes = schemes.filter { !$0.isEmpty }
                    DispatchQueue.main.async {
                        self.view?.updateData(data)
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    self.view?.updateData(data)
                }
            }
        }
    }
    
    func cancelAllScripts() {
        shellManager.cancelAllScripts()
    }
    
    func runScripts(_ scripts: [Script]) {
        command.setScripts(scripts)
        guard !command.scripts.isEmpty else { return }
        
        let settingsManager: SettingsManagerProtocol = SettingsManager.shared
        let folder = settingsManager.getFolder().pathForProcess
        command.scripts.forEach { script in
            shellManager.shell(.generateFramework(path: path, folder: folder, command: command, script: script)) {
                switch $0 {
                case .success(let result):
                    switch result {
                    case let .output(message, log):
                        debugPrint(log)
                        if scripts.count >= 1, scripts.last == script {
                            DispatchQueue.main.async {
                                self.view?.scriptsDidCompete(with: nil, message: message)
                            }
                        }
                    }
                case .failure(let error):
                    debugPrint(error.localizedDescription)
                    DispatchQueue.main.async {
                        self.view?.scriptsDidCompete(with: error, message: nil)
                    }
                }
            }
        }
    }
    
    private func xcodeVersionCheck() {
        shellManager.shell(.xcodeVersion) {
            switch $0 {
            case .success(let success):
                debugPrint(success)
            case .failure(let failure):
                debugPrint(failure)
            }
        }
    }
    
}
