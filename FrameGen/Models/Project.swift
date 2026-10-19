//
//  Project.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Observation

/// An opened Xcode project and the build options chosen for it. Options persist per project.
@Observable
final class Project {

    enum InfoState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    // MARK: - Properties

    let fileURL: URL
    let build = BuildState()
    private(set) var infoState: InfoState = .loading
    private(set) var schemes: [String] = []
    private(set) var configurations: [String] = []

    var scheme: String? {
        didSet { save() }
    }
    var configuration: String? {
        didSet { save() }
    }
    var platforms: Set<Platform> {
        didSet { save() }
    }
    /// `nil` means the default location from Settings.
    var customOutputDirectory: URL? {
        didSet { save() }
    }

    var name: String {
        fileURL.deletingPathExtension().lastPathComponent
    }

    var outputDirectory: URL {
        customOutputDirectory ?? Preferences.defaultOutputDirectory(for: fileURL)
    }

    var selectedPlatforms: [Platform] {
        Platform.allCases.filter(platforms.contains)
    }

    var canBuild: Bool {
        infoState == .loaded && scheme != nil && configuration != nil && !platforms.isEmpty && !build.isRunning
    }

    // MARK: - Initial methods

    init(fileURL: URL) {
        self.fileURL = fileURL
        let settings = Preferences.settings(for: fileURL)
        scheme = settings.scheme
        configuration = settings.configuration
        platforms = Set(settings.platforms)
        customOutputDirectory = settings.outputPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    // MARK: - Public methods

    func loadInfo() async {
        infoState = .loading
        do {
            let info = try await ProjectInfo.load(project: fileURL)
            schemes = info.schemes
            configurations = info.configurations
            if scheme.map(schemes.contains) != true {
                scheme = schemes.first { $0 == name } ?? schemes.first
            }
            if configuration.map(configurations.contains) != true {
                configuration = configurations.first { $0 == "Release" } ?? configurations.last
            }
            infoState = schemes.isEmpty ? .failed("The project has no shared or user schemes.") : .loaded
        } catch ProcessError.failed(_, let output) {
            let message = output
                .components(separatedBy: .newlines)
                .first { $0.contains("error:") } ?? output.trimmingCharacters(in: .whitespacesAndNewlines)
            infoState = .failed(message.isEmpty ? "xcodebuild could not read the project." : message)
        } catch {
            infoState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Private methods

    private func save() {
        let settings = ProjectSettings(scheme: scheme,
                                       configuration: configuration,
                                       platforms: selectedPlatforms,
                                       outputPath: customOutputDirectory?.path)
        Preferences.setSettings(settings, for: fileURL)
    }

}
