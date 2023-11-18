//
//  ShellManager.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Foundation

protocol ShellManagerProtocol: AnyObject {
    
    func shell(_ commandType: ShellManager.CommandType, completionHandler: @escaping (Result<ShellManager.ResultType, Error>) -> Void)
    func cancelAllScripts()
    
}

final class ShellManager: ShellManagerProtocol {
    
    // MARK: - Properties
    
    enum CommandType {
        case xcodeVersion
        case getSchemesFromProject(String)
        case generateFramework(path: String, folder: String, command: Command, script: Script)
        case custom(String)
        
        var command: String {
            switch self {
            case .xcodeVersion:
                return "/usr/bin/xcodebuild -version"
            case .getSchemesFromProject(let path):
                return "cd \(path); xcodebuild -list"
            case let .generateFramework(path, folder, command, script):
                return """
        cd \(path);
        xcodebuild archive \
        -scheme '\(command.scheme)' \
        -configuration \(command.configuration) \
        -destination '\(script.destination)' \
        -archivePath '\(folder)\(command.scheme)\(script.archiveName)' \
        SKIP_INSTALL=NO \
        BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
        """
            case .custom(let command):
                return command
            }
        }
    }
    
    enum ResultType {
        case output(message: String, log: String)
    }
    
    private let queue = OperationQueue()
    private var process: Process?
    
    // MARK: - Initial methods
    
    required init() {
        queue.name = "Shell Queue"
        queue.qualityOfService = .default
        queue.maxConcurrentOperationCount = 1
    }
    
    // MARK: - Public methods
    
    func cancelAllScripts() {
        queue.cancelAllOperations()
        if process?.isRunning == true {
            process?.terminate()
            process = nil
        }
    }
    
    func shell(_ commandType: CommandType, completionHandler: @escaping (Result<ShellManager.ResultType, Error>) -> Void) {
        queue.addBarrierBlock { [weak self] in
            guard let self else { return }
            
            let task = Process()
            self.process = task
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", commandType.command]
            
            let outputPipe = Pipe()
            task.standardOutput = outputPipe
            let errorPipe = Pipe()
            task.standardError = errorPipe
            
            do {
                try task.run()
            } catch {
                completionHandler(.failure(error))
            }
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                completionHandler(.failure(TaskError.parsingError(data: outputData)))
                
                return
            }
            
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            guard let errorOutput = String(data: errorData, encoding: .utf8) else {
                completionHandler(.failure(TaskError.parsingError(data: errorData)))
                
                return
            }
            
            task.waitUntilExit()
            let status = Int(task.terminationStatus)
            
            switch task.terminationReason {
            case .uncaughtSignal:
                completionHandler(.success(.output(message: "The operation was canceled.",
                                                   log: output)))
            default:
                if status == .zero {
                    let message: String
                    switch commandType {
                    case .xcodeVersion, .getSchemesFromProject, .custom:
                        message = ""
                    case .generateFramework:
                        message = "Framework generation completed successfully."
                    }
                    completionHandler(.success(.output(message: message, log: output)))
                } else {
                    completionHandler(.failure(TaskError.taskFailure(code: status, message: errorOutput)))
                }
            }
        }
    }
    
}
