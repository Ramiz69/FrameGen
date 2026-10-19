//
//  TestSupport.swift
//  FrameGenCLITests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// A unique folder in the temporary directory, removed when the value is released.
final class TemporaryDirectory {
    
    let url: URL
    
    init() throws {
        // /var is a symlink to /private/var and FileManager listings return the /private form.
        // URL.resolvingSymlinksInPath() strips /private again, so realpath(3) gives the canonical root.
        let root = FileManager.default.temporaryDirectory
        let canonicalRoot = realpath(root.path, nil).map { pointer in
            defer { free(pointer) }

            return URL(fileURLWithPath: String(cString: pointer), isDirectory: true)
        } ?? root
        url = canonicalRoot.appendingPathComponent("FrameGenCLITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    deinit {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Creates the folder (and its parents) at a path relative to the temporary directory.
    @discardableResult
    func makeDirectory(_ path: String) throws -> URL {
        let directory = url.appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        return directory
    }
    
    /// Writes a file (creating its parent folders) at a path relative to the temporary directory.
    @discardableResult
    func makeFile(_ path: String, contents: Data = Data()) throws -> URL {
        let file = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: file)
        
        return file
    }
    
}

/// Collects the lines `FrameGenTool.run` prints, from whichever thread prints them.
final class OutputRecorder: @unchecked Sendable {

    private let lock = NSLock()
    private var storage: [String] = []

    var lines: [String] {
        lock.withLock { storage }
    }

    var text: String {
        lines.joined(separator: "\n")
    }

    func record(_ line: String) {
        lock.withLock { storage.append(line) }
    }

}

/// Runs `git` in a folder, for tests that need a repository with an origin remote.
func runGit(_ arguments: [String], in directory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["-C", directory.path] + arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw CocoaError(.executableLoad, userInfo: [NSLocalizedDescriptionKey: "git \(arguments.joined(separator: " ")) failed"])
    }
}
