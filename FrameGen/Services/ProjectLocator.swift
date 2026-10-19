//
//  ProjectLocator.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 18.05.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit
import UniformTypeIdentifiers

enum ProjectLocator {

    static let projectType = UTType("com.apple.xcode.project") ?? .package

    /// Accepts an `.xcodeproj` or a folder and returns the project file to build.
    /// Folders are searched a few levels deep only, so dropping a home folder stays fast.
    static func projectFile(for url: URL, maxDepth: Int = 3) -> URL? {
        if url.pathExtension == "xcodeproj" {
            return url
        }
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true, url.path != "/" else {
            return nil
        }

        var level = [url]
        for _ in 0..<maxDepth {
            var nextLevel: [URL] = []
            for directory in level {
                let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                             includingPropertiesForKeys: [.isDirectoryKey],
                                                                             options: [.skipsHiddenFiles, .skipsPackageDescendants])) ?? []
                let sorted = contents.sorted { $0.lastPathComponent < $1.lastPathComponent }
                if let project = sorted.first(where: { $0.pathExtension == "xcodeproj" }) {
                    return project
                }
                nextLevel += sorted.filter {
                    (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && $0.pathExtension.isEmpty
                }
            }
            level = nextLevel
        }

        return nil
    }

    @MainActor
    static func chooseProject() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.message = "Choose an Xcode project or a folder that contains one."
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [projectType, .folder]

        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func chooseFolder(title: String, startingAt directory: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory

        return panel.runModal() == .OK ? panel.url : nil
    }

}
