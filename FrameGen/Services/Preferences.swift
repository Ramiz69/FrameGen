//
//  Preferences.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 07.05.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// Keys shared by `@AppStorage` in the Settings window and the models.
enum PreferenceKey {
    static let outputLocation = "outputLocation"
    static let customOutputPath = "customOutputPath"
    static let revealInFinder = "revealInFinder"
    static let keepArchives = "keepArchives"
    static let recentProjects = "recentProjects"
    static let projectSettings = "projectSettings"
}

enum OutputLocation: String, CaseIterable, Identifiable {
    case insideProject
    case customFolder

    var id: String { rawValue }
}

/// What FrameGen remembers about each project between launches.
nonisolated struct ProjectSettings: Codable, Equatable, Sendable {
    var scheme: String?
    var configuration: String?
    var platforms: [Platform] = Platform.allCases
    var outputPath: String?
}

enum Preferences {

    private static let defaults = UserDefaults.standard
    private static let maxRecentProjects = 10

    static func registerDefaults() {
        defaults.register(defaults: [PreferenceKey.outputLocation: OutputLocation.insideProject.rawValue,
                                     PreferenceKey.revealInFinder: false,
                                     PreferenceKey.keepArchives: true])
    }

    // MARK: - Output

    static var keepArchives: Bool {
        defaults.bool(forKey: PreferenceKey.keepArchives)
    }

    static var revealInFinder: Bool {
        defaults.bool(forKey: PreferenceKey.revealInFinder)
    }

    /// `<project folder>/build`, or `<custom folder>/<project name>` when a shared folder is set in Settings.
    static func defaultOutputDirectory(for projectFileURL: URL) -> URL {
        let projectDirectory = projectFileURL.deletingLastPathComponent()
        let location = OutputLocation(rawValue: defaults.string(forKey: PreferenceKey.outputLocation) ?? "") ?? .insideProject
        if location == .customFolder, let path = defaults.string(forKey: PreferenceKey.customOutputPath), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
                .appendingPathComponent(projectFileURL.deletingPathExtension().lastPathComponent, isDirectory: true)
        }

        return projectDirectory.appendingPathComponent("build", isDirectory: true)
    }

    // MARK: - Recent projects

    static var recentProjects: [URL] {
        (defaults.stringArray(forKey: PreferenceKey.recentProjects) ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func setRecentProjects(_ urls: [URL]) {
        defaults.set(urls.prefix(maxRecentProjects).map(\.path), forKey: PreferenceKey.recentProjects)
    }

    // MARK: - Per-project settings

    static func settings(for projectFileURL: URL) -> ProjectSettings {
        allProjectSettings()[projectFileURL.path] ?? ProjectSettings()
    }

    static func setSettings(_ settings: ProjectSettings, for projectFileURL: URL) {
        var all = allProjectSettings()
        all[projectFileURL.path] = settings
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: PreferenceKey.projectSettings)
        }
    }

    private static func allProjectSettings() -> [String: ProjectSettings] {
        guard let data = defaults.data(forKey: PreferenceKey.projectSettings) else { return [:] }

        return (try? JSONDecoder().decode([String: ProjectSettings].self, from: data)) ?? [:]
    }

}
