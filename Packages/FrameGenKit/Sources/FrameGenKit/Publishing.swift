//
//  Publishing.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// Where a built zip is uploaded. GitHub uses the `gh` CLI; every other host (GitLab, Bitbucket, S3,
/// Artifactory, Nexus, an internal server) is reached through a shell command template.
public enum PublishDestination: Equatable, Codable, Sendable {
    case gitHub(GitHubRelease)
    case command(CommandPublish)
}

public struct GitHubRelease: Equatable, Codable, Sendable {
    public var remote: GitRemote
    /// The release tag, e.g. `v{version}`.
    public var tagTemplate: String
    public var isDraft: Bool

    public init(remote: GitRemote, tagTemplate: String = "v{version}", isDraft: Bool = false) {
        self.remote = remote
        self.tagTemplate = tagTemplate
        self.isDraft = isDraft
    }
}

public struct CommandPublish: Equatable, Codable, Sendable {
    /// Runs with `zsh -l -c`, so variables from `~/.zprofile` (tokens, PATH) are available.
    public var commandTemplate: String
    /// Where SwiftPM downloads the uploaded zip from.
    public var downloadURLTemplate: String

    public init(commandTemplate: String, downloadURLTemplate: String) {
        self.commandTemplate = commandTemplate
        self.downloadURLTemplate = downloadURLTemplate
    }
}

/// A Git remote such as `git@github.com:owner/repo.git` or `https://gitlab.company.com/group/repo`.
public struct GitRemote: Hashable, Codable, Sendable {

    public var host: String
    /// `owner/repo`; GitLab subgroups keep every path component.
    public var path: String

    public init(host: String, path: String) {
        self.host = host
        self.path = path
    }

    /// Parses SSH (`git@host:path`, `ssh://git@host[:port]/path`) and HTTPS remotes.
    public init?(remoteURL: String) {
        var text = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix(".git") {
            text.removeLast(4)
        }
        if text.hasSuffix("/") {
            text.removeLast()
        }

        if !text.contains("://"), let colon = text.firstIndex(of: ":"), let at = text.firstIndex(of: "@"), at < colon {
            host = String(text[text.index(after: at)..<colon])
            path = String(text[text.index(after: colon)...])
        } else if let url = URL(string: text), let urlHost = url.host, ["ssh", "https", "http", "git"].contains(url.scheme ?? "") {
            host = urlHost
            path = String(url.path.drop(while: { $0 == "/" }))
        } else {
            return nil
        }
        guard !host.isEmpty, path.split(separator: "/").count >= 2 else { return nil }
    }

    /// `git remote get-url origin` for the folder, if it is inside a Git repository.
    @concurrent
    public static func origin(of directory: URL) async -> GitRemote? {
        let runner = ProcessRunner(executableURL: URL(fileURLWithPath: "/usr/bin/git"),
                                   arguments: ["-C", directory.path, "remote", "get-url", "origin"],
                                   mergesStandardError: false)
        guard let output = try? await runner.output() else { return nil }

        return GitRemote(remoteURL: output)
    }

    public var isGitHub: Bool {
        host == "github.com"
    }

}

public enum Publisher {

    /// Uploads the zip and returns the URL SwiftPM can download it from.
    public static func publish(_ summary: XCFrameworkBuilder.Summary,
                               version: String?,
                               to destination: PublishDestination,
                               onLog: (String) -> Void) async throws -> URL {
        let values = Template.Values(name: summary.plan.frameworkName,
                                     version: version,
                                     zip: summary.plan.zipURL.lastPathComponent,
                                     path: summary.plan.zipURL.path,
                                     checksum: summary.checksum)
        switch destination {
        case .gitHub(let release):
            return try await publishToGitHub(summary, values: values, release: release, onLog: onLog)
        case .command(let publish):
            let downloadURL = try Template(publish.downloadURLTemplate).url(with: values)
            let command = try Template(publish.commandTemplate).command(with: values)
            let runner = ProcessRunner(executableURL: URL(fileURLWithPath: "/bin/zsh"),
                                       arguments: ["-l", "-c", command],
                                       environment: ProcessRunner.toolEnvironment())
            for try await line in runner.lines() {
                onLog(line)
            }

            return downloadURL
        }
    }

    // MARK: - Private methods

    private static func publishToGitHub(_ summary: XCFrameworkBuilder.Summary,
                                        values: Template.Values,
                                        release: GitHubRelease,
                                        onLog: (String) -> Void) async throws -> URL {
        guard let ghURL = ProcessRunner.findTool(named: "gh") else { throw PublishError.gitHubCLIMissing }

        let tag = try Template(release.tagTemplate).string(with: values)
        let environment = ProcessRunner.toolEnvironment(adding: ["GH_PROMPT_DISABLED": "1", "NO_COLOR": "1", "GH_HOST": release.remote.host])
        let repository = ["--repo", "\(release.remote.host)/\(release.remote.path)"]
        func gh(_ arguments: [String]) -> ProcessRunner {
            ProcessRunner(executableURL: ghURL, arguments: arguments, environment: environment)
        }

        let releaseExists = (try? await gh(["release", "view", tag] + repository).output()) != nil
        let arguments = releaseExists
            ? ["release", "upload", tag, summary.plan.zipURL.path, "--clobber"] + repository
            : ["release", "create", tag, summary.plan.zipURL.path, "--title", "\(summary.plan.frameworkName) \(values.version ?? tag)",
               "--notes", "SwiftPM checksum: \(summary.checksum)"] + (release.isDraft ? ["--draft"] : []) + repository
        for try await line in gh(arguments).lines() {
            onLog(line)
        }

        guard let url = URL(string: "https://\(release.remote.host)/\(release.remote.path)/releases/download/\(tag)/\(values.zip)") else {
            throw TemplateError.invalidURL(tag)
        }

        return url
    }

}

public enum PublishError: LocalizedError, Equatable {
    case gitHubCLIMissing

    public var errorDescription: String? {
        switch self {
        case .gitHubCLIMissing:
            return "GitHub CLI isn't installed. Install it with “brew install gh” and sign in with “gh auth login”."
        }
    }
}

/// Starting points for the command destination; users replace the placeholders in angle brackets.
public enum PublishPreset: String, CaseIterable, Sendable {
    case gitLabPackageRegistry
    case bitbucketDownloads
    case amazonS3
    case artifactory

    public var commandTemplate: String {
        switch self {
        case .gitLabPackageRegistry:
            return #"curl --fail-with-body --header "PRIVATE-TOKEN: $GITLAB_TOKEN" --upload-file {path} "https://gitlab.com/api/v4/projects/<project-id>/packages/generic/{name}/{version}/{zip}""#
        case .bitbucketDownloads:
            return #"curl --fail-with-body --user "$BITBUCKET_USER:$BITBUCKET_APP_PASSWORD" --form files=@{path} "https://api.bitbucket.org/2.0/repositories/<workspace>/<repository>/downloads""#
        case .amazonS3:
            return #"aws s3 cp {path} "s3://<bucket>/{name}/{version}/{zip}""#
        case .artifactory:
            return #"curl --fail-with-body --user "$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN" --upload-file {path} "https://<company>.jfrog.io/artifactory/<repository>/{name}/{version}/{zip}""#
        }
    }

    public var downloadURLTemplate: String {
        switch self {
        case .gitLabPackageRegistry:
            return "https://gitlab.com/api/v4/projects/<project-id>/packages/generic/{name}/{version}/{zip}"
        case .bitbucketDownloads:
            return "https://bitbucket.org/<workspace>/<repository>/downloads/{zip}"
        case .amazonS3:
            return "https://<bucket>.s3.amazonaws.com/{name}/{version}/{zip}"
        case .artifactory:
            return "https://<company>.jfrog.io/artifactory/<repository>/{name}/{version}/{zip}"
        }
    }

}
