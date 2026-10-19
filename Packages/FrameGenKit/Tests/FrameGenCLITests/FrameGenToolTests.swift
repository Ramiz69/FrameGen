//
//  FrameGenToolTests.swift
//  FrameGenCLITests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
import FrameGenKit
@testable import FrameGenCLI

@Suite("The framegen command-line tool")
struct FrameGenToolTests {

    private struct Result {
        let status: Int32
        let output: OutputRecorder
        let diagnostics: OutputRecorder
    }

    private func run(_ arguments: [String], currentDirectory: URL = URL(fileURLWithPath: "/")) async -> Result {
        let output = OutputRecorder()
        let diagnostics = OutputRecorder()
        let status = await FrameGenTool.run(arguments,
                                            currentDirectory: currentDirectory,
                                            output: { output.record($0) },
                                            diagnostics: { diagnostics.record($0) })

        return Result(status: status, output: output, diagnostics: diagnostics)
    }

    // MARK: - Exit codes

    @Test("Exit codes follow shell conventions")
    func exitCodes() {
        #expect(FrameGenTool.ExitCode.success == 0)
        #expect(FrameGenTool.ExitCode.failure == 1)
        #expect(FrameGenTool.ExitCode.usage == 2)
        #expect(FrameGenTool.ExitCode.canceled == 130)
    }

    // MARK: - help and --version

    @Test("help prints the usage to stdout and succeeds", arguments: [["help"], ["--help"], ["-h"], []])
    func help(arguments: [String]) async {
        let result = await run(arguments)

        #expect(result.status == FrameGenTool.ExitCode.success)
        #expect(result.output.lines == [FrameGenTool.usage])
        #expect(result.diagnostics.lines.isEmpty)
    }

    @Test("The usage lists every command, option and platform")
    func usageContents() {
        let usage = FrameGenTool.usage

        for command in ["build", "list", "identities", "help"] {
            #expect(usage.contains("  \(command) "))
        }
        for option in ["--project", "--workspace", "--scheme", "--configuration", "--platform", "--output", "--sign",
                       "--no-archives", "--version", "--download-url", "--publish", "--tag", "--draft",
                       "--publish-command", "--json", "--verbose"] {
            #expect(usage.contains(option), "\(option) is missing from the usage")
        }
        for platform in Platform.allCases {
            #expect(usage.contains(platform.cliName))
        }
        for placeholder in Template.placeholders {
            #expect(usage.contains("{\(placeholder)}"))
        }
    }

    @Test("--version prints the tool's version")
    func version() async {
        let result = await run(["--version"])

        #expect(result.status == FrameGenTool.ExitCode.success)
        #expect(result.output.lines == ["framegen \(FrameGenTool.version)"])
        #expect(!FrameGenTool.version.isEmpty)
        #expect(result.diagnostics.lines.isEmpty)
    }

    // MARK: - Usage errors

    @Test("An unknown command prints an error and the usage to stderr", arguments: ["frobnicate", "Build", "--json"])
    func unknownCommand(command: String) async {
        let result = await run([command])

        #expect(result.status == FrameGenTool.ExitCode.usage)
        #expect(result.output.lines.isEmpty)
        #expect(result.diagnostics.lines.first == "error: Unknown command “\(command)”.\n")
        #expect(result.diagnostics.lines.last == FrameGenTool.usage)
    }

    @Test("build without options is a usage error")
    func buildWithoutOptions() async {
        let result = await run(["build"])

        #expect(result.status == FrameGenTool.ExitCode.usage)
        #expect(result.output.lines.isEmpty)
        #expect(result.diagnostics.lines == ["error: --project or --workspace is required."])
    }

    @Test("build with an unknown option is a usage error")
    func buildUnknownOption() async {
        let result = await run(["build", "--frobnicate"])

        #expect(result.status == FrameGenTool.ExitCode.usage)
        #expect(result.diagnostics.lines == ["error: " + CommandLineError.unknownOption("--frobnicate").localizedDescription])
    }

    @Test("build with an unknown platform is a usage error that lists the platforms")
    func buildUnknownPlatform() async throws {
        let directory = try TemporaryDirectory()
        try directory.makeDirectory("Kit.xcodeproj")

        let result = await run(["build", "--project", "Kit.xcodeproj", "--scheme", "Kit", "--platform", "android"],
                               currentDirectory: directory.url)

        #expect(result.status == FrameGenTool.ExitCode.usage)
        let message = try #require(result.diagnostics.lines.first)
        #expect(message.hasPrefix("error: Unknown platform “android”."))
        #expect(message.contains("visionos-simulator"))
    }

    @Test("build in a folder without a project is a usage error")
    func buildMissingProjectFolder() async throws {
        let directory = try TemporaryDirectory()

        let result = await run(["build", "--project", ".", "--scheme", "Kit"], currentDirectory: directory.url)

        #expect(result.status == FrameGenTool.ExitCode.usage)
        #expect(result.output.lines.isEmpty)
        #expect(result.diagnostics.lines == ["error: No Xcode project or workspace found at .."])
    }

    @Test("build with a missing .xcodeproj is a usage error")
    func buildMissingProject() async throws {
        let directory = try TemporaryDirectory()

        let result = await run(["build", "--project", "Nope.xcodeproj", "--scheme", "Kit"], currentDirectory: directory.url)

        #expect(result.status == FrameGenTool.ExitCode.usage)
        #expect(result.diagnostics.lines == ["error: No Xcode project or workspace found at Nope.xcodeproj."])
    }

    @Test("build --publish command without a command is a usage error and builds nothing")
    func buildPublishWithoutCommand() async throws {
        let directory = try TemporaryDirectory()
        try directory.makeDirectory("Kit.xcodeproj")

        let result = await run(["build", "--project", "Kit.xcodeproj", "--scheme", "Kit", "--platform", "ios",
                                "--publish", "command", "--download-url", "https://host/{zip}"],
                               currentDirectory: directory.url)

        #expect(result.status == FrameGenTool.ExitCode.usage)
        #expect(result.diagnostics.lines == ["error: --publish-command is required."])
        #expect(!FileManager.default.fileExists(atPath: directory.url.appendingPathComponent("build").path))
    }

    @Test("list with an unknown option or a missing value is a usage error")
    func listUsageErrors() async {
        let unknown = await run(["list", "--frobnicate"])
        let missing = await run(["list", "--project"])

        #expect(unknown.status == FrameGenTool.ExitCode.usage)
        #expect(unknown.diagnostics.lines == ["error: " + CommandLineError.unknownOption("--frobnicate").localizedDescription])
        #expect(missing.status == FrameGenTool.ExitCode.usage)
        #expect(missing.diagnostics.lines == ["error: --project needs a value."])
    }

    @Test("list in a folder without a project is a usage error")
    func listWithoutProject() async throws {
        let directory = try TemporaryDirectory()

        let result = await run(["list"], currentDirectory: directory.url)

        #expect(result.status == FrameGenTool.ExitCode.usage)
        #expect(result.output.lines.isEmpty)
        // `list` reports the resolved, standardized path (standardizing turns /private/var into /var).
        let resolved = URL(fileURLWithPath: ".", relativeTo: directory.url).standardizedFileURL.path
        #expect(result.diagnostics.lines == ["error: No Xcode project or workspace found at \(resolved)."])
    }

    // MARK: - Step names

    @Test("Every step has a readable name")
    func stepNames() {
        #expect(FrameGenTool.describe(.archive(.iOSSimulator)) == "Archive for ios-simulator")
        #expect(FrameGenTool.describe(.createXCFramework) == "Create XCFramework")
        #expect(FrameGenTool.describe(.sign) == "Sign XCFramework")
        #expect(FrameGenTool.describe(.package) == "Zip and compute checksum")
    }

}
