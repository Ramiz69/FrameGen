//
//  Workspace.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import FrameGenKit
import Foundation
import Observation

enum WorkspaceError: LocalizedError {
    case projectNotFound(URL)
    
    var errorDescription: String? {
        switch self {
        case .projectNotFound(let url):
            return String(localized: "“\(url.lastPathComponent)” doesn’t contain an Xcode project or workspace.")
        }
    }
    
    var recoverySuggestion: String? {
        String(localized: "Choose an .xcodeproj or .xcworkspace, or the folder that contains it.")
    }
}

/// The app-wide state: the opened project and the recently opened ones.
@Observable
final class Workspace {
    
    // MARK: - Properties
    
    private(set) var project: Project?
    private(set) var recentProjects: [ProjectContainer] = Preferences.recentProjects {
        didSet { Preferences.setRecentProjects(recentProjects) }
    }
    
    // MARK: - Public methods
    
    func open(_ url: URL) throws {
        guard let container = ProjectLocator.container(for: url) else {
            throw WorkspaceError.projectNotFound(url)
        }
        
        recentProjects = [container] + recentProjects.filter { $0 != container }
        guard project?.container != container else { return }
        
        let project = Project(container: container)
        self.project = project
        Task {
            await project.load()
        }
    }
    
    func closeProject() {
        project = nil
    }
    
    func removeRecentProject(_ container: ProjectContainer) {
        recentProjects.removeAll { $0 == container }
    }
    
    func clearRecentProjects() {
        recentProjects = []
    }
    
}
