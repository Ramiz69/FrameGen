//
//  ProjectInfo.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// Schemes and build configurations of a project or workspace, from `xcodebuild -list -json`.
public struct ProjectInfo: Decodable, Equatable, Sendable {

    public let schemes: [String]
    public let configurations: [String]

    public init(schemes: [String], configurations: [String]) {
        self.schemes = schemes
        self.configurations = configurations
    }

    private enum CodingKeys: String, CodingKey {
        case project
        case workspace
    }

    private struct Listing: Decodable {
        let schemes: [String]?
        let configurations: [String]?
    }

    /// Reads either form of the output. Workspaces list no configurations, so they fall back to Debug and Release.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let listing = try container.decodeIfPresent(Listing.self, forKey: .project)
            ?? container.decode(Listing.self, forKey: .workspace)
        schemes = listing.schemes ?? []
        if let configurations = listing.configurations, !configurations.isEmpty {
            self.configurations = configurations
        } else {
            configurations = container.contains(.project) ? ["Release"] : ["Debug", "Release"]
        }
    }

    @concurrent
    public static func load(_ container: ProjectContainer) async throws -> ProjectInfo {
        let output = try await XcodeCommand.list(container).output()
        let info = try JSONDecoder().decode(ProjectInfo.self, from: Data(output.utf8))
        guard
            container.kind == .workspace,
            let projectURL = mainProject(inWorkspace: container.url),
            let project = ProjectContainer(url: projectURL),
            let projectOutput = try? await XcodeCommand.list(project).output(),
            let projectInfo = try? JSONDecoder().decode(ProjectInfo.self, from: Data(projectOutput.utf8))
        else {
            return info
        }

        // A workspace has no configurations of its own; its app or framework project defines them.
        return ProjectInfo(schemes: info.schemes, configurations: projectInfo.configurations)
    }

    /// The first project referenced by the workspace that isn't CocoaPods' `Pods.xcodeproj`.
    public static func mainProject(inWorkspace workspaceURL: URL) -> URL? {
        let dataURL = workspaceURL.appendingPathComponent("contents.xcworkspacedata")
        guard let document = try? XMLDocument(contentsOf: dataURL) else { return nil }

        let locations = ((try? document.nodes(forXPath: "//FileRef/@location")) ?? []).compactMap(\.stringValue)
        let baseURL = workspaceURL.deletingLastPathComponent()

        return locations
            .compactMap { location -> URL? in
                guard let separator = location.firstIndex(of: ":") else { return nil }

                let path = String(location[location.index(after: separator)...])
                switch location[..<separator] {
                case "absolute":
                    return URL(fileURLWithPath: path)
                case "group", "container", "self":
                    return baseURL.appendingPathComponent(path)
                default:
                    return nil
                }
            }
            .filter { $0.pathExtension == "xcodeproj" && $0.deletingPathExtension().lastPathComponent != "Pods" }
            .first
    }

}
