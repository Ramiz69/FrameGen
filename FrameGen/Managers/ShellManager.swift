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
        case createXCFramework(slices: [XCFrameworkBuilder.Slice], output: URL)
        case zip(source: URL, destination: URL)
        case custom(String)
        
        var executableURL: URL {
            switch self {
            case .xcodeVersion, .getSchemesFromProject, .generateFramework, .createXCFramework:
                return URL(fileURLWithPath: "/usr/bin/xcodebuild")
            case .zip:
                return URL(fileURLWithPath: "/usr/bin/ditto")
            case .custom:
                return URL(fileURLWithPath: "/bin/bash")
            }
        }
        
        var arguments: [String] {
            switch self {
            case .xcodeVersion:
                return ["-version"]
            case .getSchemesFromProject:
                return ["-list"]
            case let .generateFramework(path, folder, command, script):
                return ["archive",
                        "-scheme", command.scheme,
                        "-configuration", command.configuration,
                        "-destination", script.destination,
                        "-archivePath", Self.archivePath(projectPath: path, folder: folder, command: command, script: script),
                        "SKIP_INSTALL=NO",
                        "BUILD_LIBRARIES_FOR_DISTRIBUTION=YES",
                        // Recent Xcode versions no longer derive these from BUILD_LIBRARIES_FOR_DISTRIBUTION,
                        // and -create-xcframework refuses Swift frameworks without a .swiftinterface.
                        "SWIFT_ENABLE_LIBRARY_EVOLUTION=YES",
                        "SWIFT_EMIT_MODULE_INTERFACE=YES"]
            case let .createXCFramework(slices, output):
                let sliceArguments = slices.flatMap { slice in
                    ["-framework", slice.frameworkURL.path] + slice.debugSymbolURLs.flatMap { ["-debug-symbols", $0.path] }
                }
                
                return ["-create-xcframework"] + sliceArguments + ["-output", output.path]
            case let .zip(source, destination):
                return ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, destination.path]
            case .custom(let command):
                return ["-c", command]
            }
        }
        
        var currentDirectoryURL: URL? {
            switch self {
            case .getSchemesFromProject(let path), .generateFramework(let path, _, _, _):
                return URL(fileURLWithPath: path, isDirectory: true)
            case .xcodeVersion, .createXCFramework, .zip, .custom:
                return nil
            }
        }
        
        static func archivePath(projectPath: String, folder: String, command: Command, script: Script) -> String {
            let projectURL = URL(fileURLWithPath: projectPath, isDirectory: true)
            let folderURL = URL(fileURLWithPath: folder, isDirectory: true, relativeTo: projectURL)
            
            return folderURL
                .appendingPathComponent(command.scheme + script.archiveName)
                .standardizedFileURL
                .path
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
            task.executableURL = commandType.executableURL
            task.arguments = commandType.arguments
            task.currentDirectoryURL = commandType.currentDirectoryURL
            
            let outputPipe = Pipe()
            task.standardOutput = outputPipe
            let errorPipe = Pipe()
            task.standardError = errorPipe
            
            do {
                try task.run()
            } catch {
                self.process = nil
                completionHandler(.failure(error))
                
                return
            }
            
            // Both pipes are drained concurrently: reading them one after another
            // deadlocks once the unread pipe fills its buffer (xcodebuild is chatty).
            var errorData = Data()
            let errorReadGroup = DispatchGroup()
            errorReadGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                errorReadGroup.leave()
            }
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            errorReadGroup.wait()
            
            task.waitUntilExit()
            self.process = nil
            
            guard let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                completionHandler(.failure(TaskError.parsingError(data: outputData)))
                
                return
            }
            let errorOutput = String(decoding: errorData, as: UTF8.self)
            let status = Int(task.terminationStatus)
            
            switch task.terminationReason {
            case .uncaughtSignal:
                completionHandler(.failure(TaskError.canceled))
            default:
                if status == .zero {
                    let message: String
                    switch commandType {
                    case .xcodeVersion, .getSchemesFromProject, .createXCFramework, .zip, .custom:
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
