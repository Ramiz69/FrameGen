//
//  Workspace.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Observation

enum WorkspaceError: LocalizedError {
    case projectNotFound(URL)

    var errorDescription: String? {
        switch self {
        case .projectNotFound(let url):
            return "“\(url.lastPathComponent)” doesn’t contain an Xcode project."
        }
    }

    var recoverySuggestion: String? {
        "Choose an .xcodeproj file or the folder that contains it."
    }
}

/// The app-wide state: the opened project and the recently opened ones.
@Observable
final class Workspace {

    // MARK: - Properties

    private(set) var project: Project?
    private(set) var recentProjects: [URL] = Preferences.recentProjects {
        didSet { Preferences.setRecentProjects(recentProjects) }
    }

    // MARK: - Public methods

    func open(_ url: URL) throws {
        guard let fileURL = ProjectLocator.projectFile(for: url) else {
            throw WorkspaceError.projectNotFound(url)
        }

        recentProjects = [fileURL] + recentProjects.filter { $0 != fileURL }
        guard project?.fileURL != fileURL else { return }

        let project = Project(fileURL: fileURL)
        self.project = project
        Task {
            await project.loadInfo()
        }
    }

    func closeProject() {
        project = nil
    }

    func removeRecentProject(_ url: URL) {
        recentProjects.removeAll { $0 == url }
    }

    func clearRecentProjects() {
        recentProjects = []
    }

}
