//
//  BuildRequest+CommandLine.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// `framegen build` options, parsed into a request. FrameGen.app prints a request back
/// with `commandLine()`, and tests round-trip the two so they never drift apart.
public struct BuildArguments: Equatable, Sendable {

    public var request: BuildRequest
    /// The `--sign` value, a SHA-1 or a certificate name, resolved against the keychain by the caller.
    public var signQuery: String?
    /// `true` when no `--platform` was given, so the caller builds every supported platform.
    public var usesDetectedPlatforms: Bool
    public var publish: PublishDestination?
    public var printsJSON: Bool
    public var isVerbose: Bool

    public init(request: BuildRequest,
                signQuery: String? = nil,
                usesDetectedPlatforms: Bool = false,
                publish: PublishDestination? = nil,
                printsJSON: Bool = false,
                isVerbose: Bool = false) {
        self.request = request
        self.signQuery = signQuery
        self.usesDetectedPlatforms = usesDetectedPlatforms
        self.publish = publish
        self.printsJSON = printsJSON
        self.isVerbose = isVerbose
    }

}

public enum CommandLineError: LocalizedError, Equatable {
    case missingValue(String)
    case unknownOption(String)
    case missingOption(String)
    case invalidValue(option: String, value: String)
    case projectNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .missingValue(let option):
            return "\(option) needs a value."
        case .unknownOption(let option):
            return "Unknown option \(option). Run “framegen help” for the list of options."
        case .missingOption(let option):
            return "\(option) is required."
        case let .invalidValue(option, value):
            if option == "--platform" {
                return "Unknown platform “\(value)”. Use one of: \(Platform.allCases.map(\.cliName).joined(separator: ", "))."
            }

            return "“\(value)” isn't a valid value for \(option)."
        case .projectNotFound(let path):
            return "No Xcode project or workspace found at \(path)."
        }
    }
}

extension BuildArguments {

    /// Parses the options after `framegen build`. Relative paths resolve against `currentDirectory`.
    public init(parsing arguments: [String], currentDirectory: URL) async throws {
        var containerPath: String?
        var scheme: String?
        var configuration = "Release"
        var platforms: [Platform] = []
        var output = "build"
        var keepArchives = true
        var version: String?
        var downloadURLTemplate: String?
        var publishKind: String?
        var publishCommand: String?
        var tagTemplate = "v{version}"
        var isDraft = false
        var signQuery: String?
        var printsJSON = false
        var isVerbose = false

        var remaining = arguments[...]
        func value(for option: String) throws -> String {
            guard let value = remaining.popFirst(), !value.hasPrefix("--") else { throw CommandLineError.missingValue(option) }

            return value
        }

        while let argument = remaining.popFirst() {
            switch argument {
            case "--project", "--workspace", "--path":
                containerPath = try value(for: argument)
            case "--scheme":
                scheme = try value(for: argument)
            case "--configuration":
                configuration = try value(for: argument)
            case "--platform":
                for name in try value(for: argument).split(separator: ",") {
                    guard let platform = Platform(cliName: String(name)) else {
                        throw CommandLineError.invalidValue(option: argument, value: String(name))
                    }
                    if !platforms.contains(platform) {
                        platforms.append(platform)
                    }
                }
            case "--output":
                output = try value(for: argument)
            case "--sign":
                signQuery = try value(for: argument)
            case "--no-archives":
                keepArchives = false
            case "--version":
                version = try value(for: argument)
            case "--download-url":
                downloadURLTemplate = try value(for: argument)
            case "--publish":
                publishKind = try value(for: argument)
            case "--publish-command":
                publishCommand = try value(for: argument)
            case "--tag":
                tagTemplate = try value(for: argument)
            case "--draft":
                isDraft = true
            case "--json":
                printsJSON = true
            case "--verbose":
                isVerbose = true
            default:
                throw CommandLineError.unknownOption(argument)
            }
        }

        guard let containerPath else { throw CommandLineError.missingOption("--project or --workspace") }
        guard let scheme else { throw CommandLineError.missingOption("--scheme") }

        let containerURL = URL(fileURLWithPath: containerPath, relativeTo: currentDirectory).standardizedFileURL
        guard let container = ProjectLocator.container(for: containerURL) else {
            throw CommandLineError.projectNotFound(containerPath)
        }

        var publish: PublishDestination?
        switch publishKind {
        case nil:
            break
        case "github":
            guard let remote = await GitRemote.origin(of: container.directoryURL) else {
                throw CommandLineError.invalidValue(option: "--publish", value: "github (no GitHub origin remote)")
            }
            publish = .gitHub(GitHubRelease(remote: remote, tagTemplate: tagTemplate, isDraft: isDraft))
        case "command":
            guard let publishCommand else { throw CommandLineError.missingOption("--publish-command") }
            guard let downloadURLTemplate else { throw CommandLineError.missingOption("--download-url") }

            publish = .command(CommandPublish(commandTemplate: publishCommand, downloadURLTemplate: downloadURLTemplate))
        case let other?:
            throw CommandLineError.invalidValue(option: "--publish", value: other)
        }

        self.init(request: BuildRequest(container: container,
                                        scheme: scheme,
                                        configuration: configuration,
                                        platforms: platforms,
                                        outputDirectory: URL(fileURLWithPath: output, relativeTo: currentDirectory).standardizedFileURL,
                                        keepArchives: keepArchives,
                                        version: version,
                                        downloadURLTemplate: downloadURLTemplate),
                  signQuery: signQuery,
                  usesDetectedPlatforms: platforms.isEmpty,
                  publish: publish,
                  printsJSON: printsJSON,
                  isVerbose: isVerbose)
    }

    /// The `build` options for this request, ready to pass back to `init(parsing:currentDirectory:)`.
    public var commandLineArguments: [String] {
        var arguments = [request.container.kind == .project ? "--project" : "--workspace", request.container.url.path,
                         "--scheme", request.scheme,
                         "--configuration", request.configuration]
        if !usesDetectedPlatforms {
            arguments += ["--platform", request.orderedPlatforms.map(\.cliName).joined(separator: ",")]
        }
        // Always explicit: the tool can't read the app's output-folder setting.
        arguments += ["--output", request.outputDirectory.path]
        if let identity = request.signingIdentity {
            arguments += ["--sign", identity.sha1]
        } else if let signQuery {
            arguments += ["--sign", signQuery]
        }
        if !request.keepArchives {
            arguments.append("--no-archives")
        }
        if let version = request.version {
            arguments += ["--version", version]
        }
        switch publish {
        case .gitHub(let release)?:
            arguments += ["--publish", "github", "--tag", release.tagTemplate] + (release.isDraft ? ["--draft"] : [])
        case .command(let command)?:
            arguments += ["--publish", "command", "--publish-command", command.commandTemplate,
                          "--download-url", command.downloadURLTemplate]
        case nil:
            if let template = request.downloadURLTemplate {
                arguments += ["--download-url", template]
            }
        }
        if printsJSON {
            arguments.append("--json")
        }
        if isVerbose {
            arguments.append("--verbose")
        }

        return arguments
    }

    /// A copy-pasteable shell command.
    public func commandLine(executable: String = "framegen") -> String {
        ([executable, "build"] + commandLineArguments).map(ShellQuoting.quote).joined(separator: " ")
    }

}
