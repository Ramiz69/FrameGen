//
//  Project.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import FrameGenKit
import Foundation
import Observation

/// An opened project or workspace and the build options chosen for it. Options persist per project.
@Observable
final class Project {

    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    // MARK: - Properties

    let container: ProjectContainer
    let build = BuildState()
    private(set) var infoState: LoadState = .loading
    private(set) var schemes: [String] = []
    private(set) var configurations: [String] = []
    /// What the selected scheme's framework target supports; reloaded when the scheme changes.
    private(set) var schemeInfoState: LoadState = .loading
    private(set) var schemeInfo: SchemeBuildInfo?
    private(set) var gitRemote: GitRemote?
    private(set) var signingIdentities: [SigningIdentity] = []

    var scheme: String? {
        didSet {
            save()
            if scheme != oldValue {
                Task { await loadSchemeInfo() }
            }
        }
    }
    var configuration: String? {
        didSet { save() }
    }
    /// The platforms the user chose; `nil` means every supported one.
    var chosenPlatforms: Set<Platform>? {
        didSet { save() }
    }
    /// `nil` means the default location from Settings.
    var customOutputDirectory: URL? {
        didSet { save() }
    }
    var signingIdentity: SigningIdentity? {
        didSet { save() }
    }
    /// Overrides the scheme's MARKETING_VERSION for templates and release tags.
    var customVersion: String? {
        didSet { save() }
    }
    var distribution: DistributionMode {
        didSet { save() }
    }
    var downloadURLTemplate: String {
        didSet { save() }
    }
    var publishCommand: String {
        didSet { save() }
    }
    var tagTemplate: String {
        didSet { save() }
    }
    var publishAsDraft: Bool {
        didSet { save() }
    }

    var name: String {
        container.name
    }

    var outputDirectory: URL {
        customOutputDirectory ?? Preferences.defaultOutputDirectory(for: container)
    }

    var supportedPlatforms: Set<Platform> {
        schemeInfo?.supportedPlatforms ?? []
    }

    /// The chosen platforms the scheme actually supports, in a stable order.
    var selectedPlatforms: [Platform] {
        let chosen = chosenPlatforms ?? supportedPlatforms

        return Platform.allCases.filter { chosen.contains($0) && supportedPlatforms.contains($0) }
    }

    var version: String? {
        customVersion ?? schemeInfo?.marketingVersion
    }

    var canBuild: Bool {
        infoState == .loaded && schemeInfoState == .loaded && scheme != nil && configuration != nil
            && !selectedPlatforms.isEmpty && !build.isRunning
    }

    // MARK: - Initial methods

    init(container: ProjectContainer) {
        self.container = container
        let settings = Preferences.settings(for: container)
        scheme = settings.scheme
        configuration = settings.configuration
        chosenPlatforms = settings.platforms.map(Set.init)
        customOutputDirectory = settings.outputPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        signingIdentity = settings.signingIdentity
        customVersion = settings.version
        distribution = settings.distribution ?? .manual
        downloadURLTemplate = settings.downloadURLTemplate ?? ""
        publishCommand = settings.publishCommand ?? ""
        tagTemplate = settings.tagTemplate ?? "v{version}"
        publishAsDraft = settings.publishAsDraft ?? false
    }

    // MARK: - Public methods

    func load() async {
        async let remote = GitRemote.origin(of: container.directoryURL)
        async let identities = try? SigningIdentity.available()
        await loadInfo()
        gitRemote = await remote
        signingIdentities = await identities ?? []
        if let identity = signingIdentity, !signingIdentities.isEmpty, !signingIdentities.contains(identity) {
            // The certificate expired or was removed; don't fail every build until the user notices.
            signingIdentity = nil
        }
    }

    func loadInfo() async {
        infoState = .loading
        do {
            let info = try await ProjectInfo.load(container)
            schemes = info.schemes
            configurations = info.configurations
            if configuration.map(configurations.contains) != true {
                configuration = configurations.first { $0 == "Release" } ?? configurations.last
            }
            guard !schemes.isEmpty else {
                infoState = .failed(String(localized: "The project has no shared or user schemes."))

                return
            }

            infoState = .loaded
            if let scheme, schemes.contains(scheme) {
                await loadSchemeInfo()
            } else {
                // Setting the scheme triggers loadSchemeInfo().
                scheme = schemes.first { $0 == name } ?? schemes.first
            }
        } catch {
            infoState = .failed(Self.message(for: error))
        }
    }

    func loadSchemeInfo() async {
        guard let scheme else { return }

        schemeInfoState = .loading
        do {
            let info = try await SchemeBuildInfo.load(container, scheme: scheme)
            guard scheme == self.scheme else { return }

            schemeInfo = info
            schemeInfoState = info.supportedPlatforms.isEmpty
                ? .failed(String(localized: "The scheme “\(scheme)” doesn’t build for any platform FrameGen supports."))
                : .loaded
        } catch {
            guard scheme == self.scheme else { return }

            schemeInfo = nil
            schemeInfoState = .failed(Self.message(for: error))
        }
    }

    func setPlatform(_ platform: Platform, isOn: Bool) {
        var chosen = chosenPlatforms ?? supportedPlatforms
        if isOn {
            chosen.insert(platform)
        } else {
            chosen.remove(platform)
        }
        chosenPlatforms = chosen
    }

    /// The request for the current options, or `nil` while they are incomplete.
    func makeBuildRequest() -> BuildRequest? {
        guard let scheme, let configuration, !selectedPlatforms.isEmpty else { return nil }

        let template: String? = switch distribution {
        case .manual, .command:
            downloadURLTemplate.isEmpty ? nil : downloadURLTemplate
        case .gitHubRelease:
            nil
        }

        return BuildRequest(container: container,
                            scheme: scheme,
                            configuration: configuration,
                            platforms: selectedPlatforms,
                            outputDirectory: outputDirectory,
                            signingIdentity: signingIdentity,
                            keepArchives: Preferences.keepArchives,
                            version: version,
                            downloadURLTemplate: template)
    }

    /// Where "Publish" uploads the zip, or `nil` when distribution is manual or incomplete.
    var publishDestination: PublishDestination? {
        switch distribution {
        case .manual:
            return nil
        case .gitHubRelease:
            guard let gitRemote else { return nil }

            return .gitHub(GitHubRelease(remote: gitRemote, tagTemplate: tagTemplate, isDraft: publishAsDraft))
        case .command:
            guard !publishCommand.isEmpty, !downloadURLTemplate.isEmpty else { return nil }

            return .command(CommandPublish(commandTemplate: publishCommand, downloadURLTemplate: downloadURLTemplate))
        }
    }

    /// The equivalent `framegen build` command for CI.
    func buildCommandLine() -> String? {
        guard let request = makeBuildRequest() else { return nil }

        return BuildArguments(request: request, publish: publishDestination).commandLine()
    }

    // MARK: - Private methods

    private static func message(for error: Error) -> String {
        if case let ProcessError.failed(_, output) = error {
            let line = output.components(separatedBy: .newlines).first { $0.contains("error:") }
                ?? output.trimmingCharacters(in: .whitespacesAndNewlines)

            return line.isEmpty ? String(localized: "xcodebuild could not read the project.") : line
        }

        return error.localizedDescription
    }

    private func save() {
        var settings = ProjectSettings()
        settings.scheme = scheme
        settings.configuration = configuration
        settings.platforms = chosenPlatforms.map { Platform.allCases.filter($0.contains) }
        settings.outputPath = customOutputDirectory?.path
        settings.signingIdentity = signingIdentity
        settings.version = customVersion
        settings.distribution = distribution
        settings.downloadURLTemplate = downloadURLTemplate.isEmpty ? nil : downloadURLTemplate
        settings.publishCommand = publishCommand.isEmpty ? nil : publishCommand
        settings.tagTemplate = tagTemplate
        settings.publishAsDraft = publishAsDraft
        Preferences.setSettings(settings, for: container)
    }

}
