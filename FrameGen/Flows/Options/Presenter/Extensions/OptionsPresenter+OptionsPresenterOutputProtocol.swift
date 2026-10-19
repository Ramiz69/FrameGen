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
                    
                    data.schemes = schemes.compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
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
        
        let folder = settingsManager.getFolder().pathForProcess
        let archiveURLs = command.scripts.map { script in
            URL(fileURLWithPath: ShellManager.CommandType.archivePath(projectPath: path,
                                                                     folder: folder,
                                                                     command: command,
                                                                     script: script))
        }
        let lastScript = command.scripts.last
        // Completion handlers run one at a time on the shell queue, so the flag needs no locking.
        var didFail = false
        command.scripts.forEach { script in
            shellManager.shell(.generateFramework(path: path, folder: folder, command: command, script: script)) { [weak self] in
                guard let self, !didFail else { return }
                
                switch $0 {
                case .success(let result):
                    switch result {
                    case let .output(_, log):
                        debugPrint(log)
                        if script == lastScript {
                            self.createXCFramework(archiveURLs: archiveURLs)
                        }
                    }
                case .failure(TaskError.canceled):
                    didFail = true
                case .failure(let error):
                    debugPrint(error.localizedDescription)
                    didFail = true
                    self.shellManager.cancelAllScripts()
                    self.finish(.failure(error))
                }
            }
        }
    }
    
    private func createXCFramework(archiveURLs: [URL]) {
        let plan: XCFrameworkBuilder.Plan
        do {
            plan = try XCFrameworkBuilder.makePlan(archiveURLs: archiveURLs,
                                                   outputDirectoryURL: archiveURLs[0].deletingLastPathComponent())
        } catch {
            finish(.failure(error))
            
            return
        }
        
        shell(.createXCFramework(slices: plan.slices, output: plan.xcframeworkURL)) { [weak self] in
            self?.shell(.zip(source: plan.xcframeworkURL, destination: plan.zipURL)) { [weak self] in
                self?.finish(Result { try XCFrameworkBuilder.finalize(plan) })
            }
        }
    }
    
    /// Runs a pipeline step and reports its failure; cancellation is silent because the window is already closed.
    private func shell(_ commandType: ShellManager.CommandType, onSuccess: @escaping () -> Void) {
        shellManager.shell(commandType) { [weak self] in
            switch $0 {
            case .success:
                onSuccess()
            case .failure(TaskError.canceled):
                break
            case .failure(let error):
                debugPrint(error.localizedDescription)
                self?.finish(.failure(error))
            }
        }
    }
    
    private func finish(_ result: Result<XCFrameworkBuilder.Summary, Error>) {
        DispatchQueue.main.async {
            switch result {
            case .success(let summary):
                self.view?.scriptsDidCompete(with: nil, message: summary.message, resultURL: summary.plan.xcframeworkURL)
            case .failure(let error):
                self.view?.scriptsDidCompete(with: error, message: nil, resultURL: nil)
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
