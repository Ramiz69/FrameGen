//
//  Preferences.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 07.05.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import FrameGenKit
import Foundation

/// Keys shared by the Settings window and the models.
enum PreferenceKey {
    static let outputLocation = "outputLocation"
    static let customOutputPath = "customOutputPath"
    static let revealInFinder = "revealInFinder"
    static let keepArchives = "keepArchives"
    static let notifyWhenDone = "notifyWhenDone"
    static let recentProjects = "recentProjects"
    static let projectSettings = "projectSettings"
}

enum OutputLocation: String, CaseIterable, Identifiable {
    case insideProject
    case customFolder

    var id: String { rawValue }
}

/// How a project's zip is distributed after building.
enum DistributionMode: String, Codable, CaseIterable, Sendable {
    /// Upload by hand; an optional download URL template still fills the snippet.
    case manual
    case gitHubRelease
    case command
}

/// What FrameGen remembers about each project between launches.
///
/// Every field is optional and platforms decode leniently: a field added later, or a platform
/// removed in a future version, must never make the whole settings dictionary unreadable.
nonisolated struct ProjectSettings: Codable, Equatable, Sendable {
    var scheme: String?
    var configuration: String?
    /// `nil` means every platform the scheme supports.
    var platforms: [Platform]?
    var outputPath: String?
    var signingIdentity: SigningIdentity?
    var version: String?
    var distribution: DistributionMode?
    var downloadURLTemplate: String?
    var publishCommand: String?
    var tagTemplate: String?
    var publishAsDraft: Bool?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case scheme, configuration, platforms, outputPath, signingIdentity, version, distribution
        case downloadURLTemplate, publishCommand, tagTemplate, publishAsDraft
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheme = try? container.decodeIfPresent(String.self, forKey: .scheme)
        configuration = try? container.decodeIfPresent(String.self, forKey: .configuration)
        platforms = (try? container.decodeIfPresent([String].self, forKey: .platforms))?.compactMap(Platform.init(rawValue:))
        outputPath = try? container.decodeIfPresent(String.self, forKey: .outputPath)
        signingIdentity = try? container.decodeIfPresent(SigningIdentity.self, forKey: .signingIdentity)
        version = try? container.decodeIfPresent(String.self, forKey: .version)
        distribution = try? container.decodeIfPresent(DistributionMode.self, forKey: .distribution)
        downloadURLTemplate = try? container.decodeIfPresent(String.self, forKey: .downloadURLTemplate)
        publishCommand = try? container.decodeIfPresent(String.self, forKey: .publishCommand)
        tagTemplate = try? container.decodeIfPresent(String.self, forKey: .tagTemplate)
        publishAsDraft = try? container.decodeIfPresent(Bool.self, forKey: .publishAsDraft)
    }
}

enum Preferences {

    private static let defaults = UserDefaults.standard
    private static let maxRecentProjects = 10

    static func registerDefaults() {
        defaults.register(defaults: [PreferenceKey.outputLocation: OutputLocation.insideProject.rawValue,
                                     PreferenceKey.revealInFinder: false,
                                     PreferenceKey.keepArchives: true,
                                     PreferenceKey.notifyWhenDone: true])
    }

    // MARK: - Output

    static var keepArchives: Bool {
        defaults.bool(forKey: PreferenceKey.keepArchives)
    }

    static var revealInFinder: Bool {
        defaults.bool(forKey: PreferenceKey.revealInFinder)
    }

    static var notifyWhenDone: Bool {
        defaults.bool(forKey: PreferenceKey.notifyWhenDone)
    }

    /// `<project folder>/build`, or `<custom folder>/<project name>` when a shared folder is set in Settings.
    static func defaultOutputDirectory(for container: ProjectContainer) -> URL {
        let location = OutputLocation(rawValue: defaults.string(forKey: PreferenceKey.outputLocation) ?? "") ?? .insideProject
        if location == .customFolder, let path = defaults.string(forKey: PreferenceKey.customOutputPath), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent(container.name, isDirectory: true)
        }

        return container.directoryURL.appendingPathComponent("build", isDirectory: true)
    }

    // MARK: - Recent projects

    static var recentProjects: [ProjectContainer] {
        (defaults.stringArray(forKey: PreferenceKey.recentProjects) ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .compactMap(ProjectContainer.init(url:))
    }

    static func setRecentProjects(_ containers: [ProjectContainer]) {
        defaults.set(containers.prefix(maxRecentProjects).map(\.url.path), forKey: PreferenceKey.recentProjects)
    }

    // MARK: - Per-project settings

    /// Settings saved before workspaces were supported are keyed by the `.xcodeproj` path;
    /// they are carried over when the same project now opens through its workspace.
    static func settings(for container: ProjectContainer) -> ProjectSettings {
        let all = allProjectSettings()
        if let settings = all[container.url.path] {
            return settings
        }
        if container.kind == .workspace,
           let projectURL = ProjectInfo.mainProject(inWorkspace: container.url),
           let settings = all[projectURL.path] {
            return settings
        }

        return ProjectSettings()
    }

    static func setSettings(_ settings: ProjectSettings, for container: ProjectContainer) {
        var all = allProjectSettings()
        all[container.url.path] = settings
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: PreferenceKey.projectSettings)
        }
    }

    private static func allProjectSettings() -> [String: ProjectSettings] {
        guard let data = defaults.data(forKey: PreferenceKey.projectSettings) else { return [:] }

        return (try? JSONDecoder().decode([String: ProjectSettings].self, from: data)) ?? [:]
    }

}
