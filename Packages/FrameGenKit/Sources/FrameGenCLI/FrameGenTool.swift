//
//  FrameGenTool.swift
//  FrameGenCLI
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import FrameGenKit
import Foundation

/// The `framegen` command-line tool. Progress goes to stderr and results to stdout,
/// so `framegen build … --json | jq` works in CI.
public enum FrameGenTool {

    public enum ExitCode {
        public static let success: Int32 = 0
        public static let failure: Int32 = 1
        public static let usage: Int32 = 2
        public static let canceled: Int32 = 130
    }

    /// Runs the tool with the arguments after the executable name and returns the exit code.
    public static func run(_ arguments: [String],
                           currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                           output: @escaping (String) -> Void = { print($0) },
                           diagnostics: @escaping (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }) async -> Int32 {
        var arguments = arguments[...]
        let command = arguments.popFirst() ?? "help"
        do {
            switch command {
            case "build":
                return try await build(Array(arguments), currentDirectory: currentDirectory, output: output, diagnostics: diagnostics)
            case "list":
                return try await list(Array(arguments), currentDirectory: currentDirectory, output: output)
            case "identities":
                for identity in try await SigningIdentity.available() {
                    output("\(identity.sha1)  \(identity.name)")
                }

                return ExitCode.success
            case "help", "--help", "-h":
                output(usage)

                return ExitCode.success
            case "--version":
                output("framegen \(version)")

                return ExitCode.success
            default:
                diagnostics("error: Unknown command “\(command)”.\n")
                diagnostics(usage)

                return ExitCode.usage
            }
        } catch let error as CommandLineError {
            diagnostics("error: \(error.localizedDescription)")

            return ExitCode.usage
        } catch is CancellationError {
            return ExitCode.canceled
        } catch ProcessError.canceled {
            return ExitCode.canceled
        } catch let error as PipelineError {
            diagnostics("error: \(describe(error.step)) failed. \(error.localizedDescription)")
            error.highlights.forEach { diagnostics("  \($0)") }

            return ExitCode.failure
        } catch {
            diagnostics("error: \(error.localizedDescription)")

            return ExitCode.failure
        }
    }

    // MARK: - Commands

    private static func build(_ arguments: [String],
                              currentDirectory: URL,
                              output: @escaping (String) -> Void,
                              diagnostics: @escaping (String) -> Void) async throws -> Int32 {
        var parsed = try await BuildArguments(parsing: arguments, currentDirectory: currentDirectory)
        if parsed.usesDetectedPlatforms {
            let info = try await SchemeBuildInfo.load(parsed.request.container, scheme: parsed.request.scheme)
            parsed.request.platforms = Platform.allCases.filter(info.supportedPlatforms.contains)
            diagnostics("Building for every supported platform: \(parsed.request.orderedPlatforms.map(\.cliName).joined(separator: ", "))")
        }
        if let query = parsed.signQuery {
            parsed.request.signingIdentity = try await resolveIdentity(query)
        }

        var steps: [StepKind] = []
        let summary = try await XCFrameworkPipeline.run(parsed.request) { event in
            switch event {
            case .planned(let planned):
                steps = planned
            case .stepStarted(let index):
                diagnostics("==> [\(index + 1)/\(steps.count)] \(describe(steps[index]))")
            case let .stepFinished(_, duration):
                diagnostics("    done in \(Int(duration.rounded()))s")
            case .stepFailed:
                break
            case .log(let line):
                if parsed.isVerbose {
                    diagnostics("    \(line)")
                }
            }
        }

        var result = summary
        if let destination = parsed.publish {
            diagnostics("==> Publishing \(summary.plan.zipURL.lastPathComponent)")
            let url = try await Publisher.publish(summary, version: parsed.request.version, to: destination) { line in
                if parsed.isVerbose {
                    diagnostics("    \(line)")
                }
            }
            result = try summary.withDownloadURL(url)
        }

        output(parsed.printsJSON ? try json(for: result) : text(for: result))

        return ExitCode.success
    }

    private static func list(_ arguments: [String], currentDirectory: URL, output: (String) -> Void) async throws -> Int32 {
        var path: String?
        var scheme: String?
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            switch argument {
            case "--project", "--workspace", "--path":
                guard let value = remaining.popFirst() else { throw CommandLineError.missingValue(argument) }

                path = value
            case "--scheme":
                guard let value = remaining.popFirst() else { throw CommandLineError.missingValue(argument) }

                scheme = value
            default:
                throw CommandLineError.unknownOption(argument)
            }
        }

        let url = URL(fileURLWithPath: path ?? ".", relativeTo: currentDirectory).standardizedFileURL
        guard let container = ProjectLocator.container(for: url) else { throw CommandLineError.projectNotFound(url.path) }

        let info = try await ProjectInfo.load(container)
        output("\(container.kind == .project ? "Project" : "Workspace"): \(container.url.path)")
        output("Schemes: \(info.schemes.joined(separator: ", "))")
        output("Configurations: \(info.configurations.joined(separator: ", "))")
        if let scheme = scheme ?? info.schemes.first(where: { $0 == container.name }) ?? info.schemes.first {
            let buildInfo = try await SchemeBuildInfo.load(container, scheme: scheme)
            let platforms = Platform.allCases.filter(buildInfo.supportedPlatforms.contains).map(\.cliName)
            output("Platforms for \(scheme): \(platforms.joined(separator: ", "))")
            if let version = buildInfo.marketingVersion {
                output("Version: \(version)")
            }
        }

        return ExitCode.success
    }

    // MARK: - Helpers

    private static func resolveIdentity(_ query: String) async throws -> SigningIdentity {
        let identities = try await SigningIdentity.available()
        let matches = identities.filter { $0.sha1.caseInsensitiveCompare(query) == .orderedSame || $0.name.contains(query) }
        guard matches.count == 1, let identity = matches.first else {
            throw CommandLineError.invalidValue(option: "--sign",
                                                value: matches.isEmpty ? "\(query) (no matching identity; see “framegen identities”)"
                                                                       : "\(query) (matches \(matches.count) identities; pass the SHA-1)")
        }

        return identity
    }

    static func describe(_ step: StepKind) -> String {
        switch step {
        case .archive(let platform):
            return "Archive for \(platform.cliName)"
        case .createXCFramework:
            return "Create XCFramework"
        case .sign:
            return "Sign XCFramework"
        case .package:
            return "Zip and compute checksum"
        }
    }

    static func text(for summary: XCFrameworkBuilder.Summary) -> String {
        var lines = ["XCFramework: \(summary.plan.xcframeworkURL.path)",
                     "Zip:         \(summary.plan.zipURL.path)",
                     "Checksum:    \(summary.checksum)"]
        if let signedBy = summary.signedBy {
            lines.append("Signed by:   \(signedBy)")
        }
        if !summary.librariesWithoutPrivacyManifest.isEmpty {
            lines.append("Warning:     no PrivacyInfo.xcprivacy in \(summary.librariesWithoutPrivacyManifest.joined(separator: ", "))")
        }
        lines += ["", summary.packageSnippet.trimmingCharacters(in: .newlines)]

        return lines.joined(separator: "\n")
    }

    static func json(for summary: XCFrameworkBuilder.Summary) throws -> String {
        struct Output: Encodable {
            let xcframework: String
            let zip: String
            let checksum: String
            let downloadURL: String?
            let snippet: String
            let signedBy: String?
            let librariesWithoutPrivacyManifest: [String]
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(Output(xcframework: summary.plan.xcframeworkURL.path,
                                             zip: summary.plan.zipURL.path,
                                             checksum: summary.checksum,
                                             downloadURL: summary.downloadURL?.absoluteString,
                                             snippet: summary.packageSnippet,
                                             signedBy: summary.signedBy,
                                             librariesWithoutPrivacyManifest: summary.librariesWithoutPrivacyManifest))

        return String(decoding: data, as: UTF8.self)
    }

    /// The app's marketing version when embedded in FrameGen.app, otherwise the package build.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static let usage = """
    Usage: framegen <command> [options]

    Commands:
      build        Build an XCFramework, zip it and compute its SwiftPM checksum
      list         Show the schemes, configurations and supported platforms of a project
      identities   List the code signing identities in the keychain
      help         Show this help

    build options:
      --project <path> | --workspace <path>   .xcodeproj, .xcworkspace or a folder containing one (required)
      --scheme <name>                         Framework scheme (required)
      --configuration <name>                  Build configuration (default: Release)
      --platform <list>                       Comma-separated or repeated; default: every supported platform
                                              \(Platform.allCases.map(\.cliName).joined(separator: ", "))
      --output <folder>                       Output folder (default: ./build)
      --sign <sha1|name>                      Sign the XCFramework with this identity
      --no-archives                           Delete the intermediate .xcarchive folders
      --version <version>                     Release version for {version} in templates
      --download-url <template>               Download URL for the binaryTarget snippet, e.g.
                                              https://cdn.example.com/{name}/{version}/{zip}
      --publish github|command                Upload the zip after building
      --tag <template>                        GitHub release tag (default: v{version})
      --draft                                 Create the GitHub release as a draft
      --publish-command <template>            Shell command for --publish command; {path} is the zip
      --json                                  Print the result as JSON
      --verbose                               Print the xcodebuild log

    Templates understand {name}, {version}, {zip}, {path} and {checksum}.
    """

}
