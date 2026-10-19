//
//  ProjectInfo.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// The part of `xcodebuild -list -json` FrameGen needs.
nonisolated struct ProjectInfo: Decodable, Sendable {

    let schemes: [String]
    let configurations: [String]

    private enum CodingKeys: String, CodingKey {
        case project
    }

    private struct Project: Decodable {
        let schemes: [String]?
        let configurations: [String]?
    }

    init(from decoder: Decoder) throws {
        let project = try decoder.container(keyedBy: CodingKeys.self).decode(Project.self, forKey: .project)
        schemes = project.schemes ?? []
        configurations = project.configurations?.isEmpty == false ? project.configurations ?? [] : ["Release"]
    }

    @concurrent
    static func load(project: URL) async throws -> ProjectInfo {
        let output = try await XcodeCommand.list(project: project).output()

        return try JSONDecoder().decode(ProjectInfo.self, from: Data(output.utf8))
    }

}
