//
//  ProjectLocator.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 18.05.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

public enum ProjectLocator {

    /// Accepts an `.xcodeproj`, an `.xcworkspace` or a folder and returns what xcodebuild should build.
    /// A workspace next to a project wins, because CocoaPods projects only build through their workspace.
    /// Folders are searched a few levels deep only, so dropping a home folder stays fast.
    public static func container(for url: URL, maxDepth: Int = 3) -> ProjectContainer? {
        if let container = ProjectContainer(url: url) {
            // Both are folders on disk; a typo in a path must not reach xcodebuild.
            guard isDirectory(url) else { return nil }
            
            // The workspace inside every .xcodeproj only wraps that project.
            if container.kind == .workspace, url.deletingLastPathComponent().pathExtension == "xcodeproj" {
                return ProjectContainer(url: url.deletingLastPathComponent())
            }
            if container.kind == .project, let workspace = siblingWorkspace(of: url) {
                return workspace
            }

            return container
        }
        guard isDirectory(url), url.path != "/" else { return nil }

        var level = [url]
        for _ in 0..<maxDepth {
            var nextLevel: [URL] = []
            for directory in level {
                let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                             includingPropertiesForKeys: [.isDirectoryKey],
                                                                             options: [.skipsHiddenFiles, .skipsPackageDescendants])) ?? []
                let sorted = contents.sorted { $0.lastPathComponent < $1.lastPathComponent }
                if let workspace = sorted.first(where: { $0.pathExtension == "xcworkspace" }) {
                    return ProjectContainer(url: workspace)
                }
                if let project = sorted.first(where: { $0.pathExtension == "xcodeproj" }) {
                    return ProjectContainer(url: project)
                }
                nextLevel += sorted.filter { isDirectory($0) && $0.pathExtension.isEmpty }
            }
            level = nextLevel
        }

        return nil
    }

    // MARK: - Private methods

    private static func siblingWorkspace(of projectURL: URL) -> ProjectContainer? {
        let workspaceURL = projectURL.deletingPathExtension().appendingPathExtension("xcworkspace")

        return isDirectory(workspaceURL) ? ProjectContainer(url: workspaceURL) : nil
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

}
