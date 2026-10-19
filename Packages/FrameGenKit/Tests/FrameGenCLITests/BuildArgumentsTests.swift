//
//  BuildArgumentsTests.swift
//  FrameGenCLITests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
import FrameGenKit

@Suite("Parsing and printing framegen build options")
struct BuildArgumentsTests {

    /// A temporary folder with an empty `Kit.xcodeproj`, which is all `ProjectLocator` needs.
    private struct Fixture {
        let directory: TemporaryDirectory
        let projectURL: URL
        let container: ProjectContainer

        init(workspace: Bool = false) throws {
            directory = try TemporaryDirectory()
            try directory.makeDirectory("Kit.xcodeproj")
            if workspace {
                try directory.makeDirectory("Kit.xcworkspace")
            }
            // The form parsing produces: a standardized file URL. Standardizing an existing folder adds a
            // trailing slash and turns /private/var into /var, so a URL built any other way wouldn't compare equal.
            let name = workspace ? "Kit.xcworkspace" : "Kit.xcodeproj"
            projectURL = Self.parsedForm(directory.url.appendingPathComponent(name))
            container = try #require(ProjectContainer(url: projectURL))
        }

        static func parsedForm(_ url: URL) -> URL {
            URL(fileURLWithPath: url.path).standardizedFileURL
        }

        /// An output folder URL in the form parsing produces for a folder that doesn't exist yet.
        func outputURL(_ name: String = "build") -> URL {
            Self.parsedForm(directory.url.appendingPathComponent(name))
        }

        func parse(_ arguments: [String]) async throws -> BuildArguments {
            try await BuildArguments(parsing: arguments, currentDirectory: directory.url)
        }
    }

    private func roundTrip(_ arguments: BuildArguments, in fixture: Fixture) async throws -> BuildArguments {
        try await fixture.parse(arguments.commandLineArguments)
    }

    // MARK: - Round trips

    @Test("A minimal request round-trips")
    func roundTripMinimal() async throws {
        let fixture = try Fixture()
        let arguments = BuildArguments(request: BuildRequest(container: fixture.container,
                                                             scheme: "Kit",
                                                             platforms: [],
                                                             outputDirectory: fixture.outputURL()),
                                       usesDetectedPlatforms: true)

        let parsed = try await roundTrip(arguments, in: fixture)

        #expect(parsed == arguments)
        #expect(!arguments.commandLineArguments.contains("--platform"))
    }

    @Test("A request with every option round-trips")
    func roundTripEverything() async throws {
        let fixture = try Fixture()
        let arguments = BuildArguments(request: BuildRequest(container: fixture.container,
                                                             scheme: "My Kit",
                                                             configuration: "Staging",
                                                             platforms: [.iOS, .iOSSimulator, .macCatalyst, .visionOS],
                                                             outputDirectory: fixture.outputURL("Out Dir"),
                                                             keepArchives: false,
                                                             version: "1.2.0-beta.1",
                                                             downloadURLTemplate: "https://cdn.example.com/{name}/{version}/{zip}"),
                                       signQuery: "Apple Distribution: Company (TEAMID)",
                                       printsJSON: true,
                                       isVerbose: true)

        let parsed = try await roundTrip(arguments, in: fixture)

        #expect(parsed == arguments)
    }

    @Test("A workspace round-trips with --workspace")
    func roundTripWorkspace() async throws {
        let fixture = try Fixture(workspace: true)
        let arguments = BuildArguments(request: BuildRequest(container: fixture.container,
                                                             scheme: "Kit",
                                                             platforms: [.macOS],
                                                             outputDirectory: fixture.outputURL()))

        #expect(arguments.commandLineArguments.prefix(2) == ["--workspace", fixture.projectURL.path])
        #expect(try await roundTrip(arguments, in: fixture) == arguments)
    }

    @Test("Every single platform round-trips", arguments: Platform.allCases)
    func roundTripPlatform(platform: Platform) async throws {
        let fixture = try Fixture()
        let arguments = BuildArguments(request: BuildRequest(container: fixture.container,
                                                             scheme: "Kit",
                                                             platforms: [platform],
                                                             outputDirectory: fixture.outputURL()))

        #expect(try await roundTrip(arguments, in: fixture) == arguments)
    }

    @Test("All platforms round-trip in Platform.allCases order")
    func roundTripAllPlatforms() async throws {
        let fixture = try Fixture()
        let arguments = BuildArguments(request: BuildRequest(container: fixture.container,
                                                             scheme: "Kit",
                                                             platforms: Platform.allCases,
                                                             outputDirectory: fixture.outputURL()))

        #expect(try await roundTrip(arguments, in: fixture) == arguments)
    }

    @Test("Command publishing round-trips")
    func roundTripCommandPublish() async throws {
        let fixture = try Fixture()
        let downloadURL = "https://bucket.s3.amazonaws.com/{name}/{version}/{zip}"
        let arguments = BuildArguments(request: BuildRequest(container: fixture.container,
                                                             scheme: "Kit",
                                                             platforms: [.iOS, .iOSSimulator],
                                                             outputDirectory: fixture.outputURL(),
                                                             version: "2.0",
                                                             downloadURLTemplate: downloadURL),
                                       publish: .command(CommandPublish(commandTemplate: #"aws s3 cp {path} "s3://bucket/{name}/{version}/{zip}""#,
                                                                        downloadURLTemplate: downloadURL)))

        #expect(try await roundTrip(arguments, in: fixture) == arguments)
    }

    @Test("GitHub publishing round-trips in a repository with a GitHub origin", arguments: [false, true])
    func roundTripGitHubPublish(isDraft: Bool) async throws {
        let fixture = try Fixture()
        try runGit(["init", "-q"], in: fixture.directory.url)
        try runGit(["remote", "add", "origin", "git@github.com:o/r.git"], in: fixture.directory.url)
        let arguments = BuildArguments(request: BuildRequest(container: fixture.container,
                                                             scheme: "Kit",
                                                             platforms: [.iOS],
                                                             outputDirectory: fixture.outputURL(),
                                                             version: "3.1"),
                                       publish: .gitHub(GitHubRelease(remote: GitRemote(host: "github.com", path: "o/r"),
                                                                      tagTemplate: "release-{version}",
                                                                      isDraft: isDraft)))

        #expect(try await roundTrip(arguments, in: fixture) == arguments)
    }

    @Test("A signing identity is printed as its SHA-1, which parses back as the sign query")
    func signingIdentityPrintsSHA1() async throws {
        let fixture = try Fixture()
        let identity = SigningIdentity(sha1: "0123456789ABCDEF0123456789ABCDEF01234567", name: "Apple Distribution: Company (TEAMID)")
        let arguments = BuildArguments(request: BuildRequest(container: fixture.container,
                                                             scheme: "Kit",
                                                             platforms: [.iOS],
                                                             outputDirectory: fixture.outputURL(),
                                                             signingIdentity: identity),
                                       signQuery: "ignored")

        let printed = arguments.commandLineArguments
        let parsed = try await fixture.parse(printed)

        #expect(printed.contains(identity.sha1))
        #expect(!printed.contains("ignored"))
        #expect(parsed.signQuery == identity.sha1)
        #expect(parsed.request.signingIdentity == nil)
    }

    @Test("URLs in another form than the parser's still round-trip to the same paths")
    func roundTripOtherURLForms() async throws {
        let fixture = try Fixture()
        let container = try #require(ProjectContainer(url: fixture.directory.url.appendingPathComponent("Kit.xcodeproj", isDirectory: false)))
        let arguments = BuildArguments(request: BuildRequest(container: container,
                                                             scheme: "Kit",
                                                             platforms: [.iOS],
                                                             outputDirectory: fixture.directory.url.appendingPathComponent("build", isDirectory: true)))

        let parsed = try await roundTrip(arguments, in: fixture)

        // URL equality also compares the trailing slash and the /private prefix, so only the resolved paths can match here.
        #expect(parsed.request.container.url.resolvingSymlinksInPath().path == container.url.resolvingSymlinksInPath().path)
        #expect(parsed.request.container.kind == .project)
        #expect(parsed.request.outputDirectory.resolvingSymlinksInPath().path
                == arguments.request.outputDirectory.resolvingSymlinksInPath().path)
        #expect(parsed.request.platforms == arguments.request.platforms)
    }

    // MARK: - commandLine(executable:)

    @Test("commandLine quotes arguments for the shell")
    func commandLine() throws {
        let container = try #require(ProjectContainer(url: URL(fileURLWithPath: "/Users/me/My Kit/Kit.xcodeproj")))
        let arguments = BuildArguments(request: BuildRequest(container: container,
                                                             scheme: "Kit",
                                                             platforms: [.iOSSimulator, .iOS],
                                                             outputDirectory: URL(fileURLWithPath: "/Users/me/build")),
                                       printsJSON: true)

        #expect(arguments.commandLine() == "framegen build --project '/Users/me/My Kit/Kit.xcodeproj' --scheme Kit "
                + "--configuration Release --platform ios,ios-simulator --output /Users/me/build --json")
        #expect(arguments.commandLine(executable: "/Applications/Frame Gen.app/framegen").hasPrefix("'/Applications/Frame Gen.app/framegen' build "))
    }

    // MARK: - Parsing

    @Test("Defaults: Release, ./build, archives kept, detected platforms, nothing else")
    func defaults() async throws {
        let fixture = try Fixture()

        let parsed = try await fixture.parse(["--project", "Kit.xcodeproj", "--scheme", "Kit"])

        #expect(parsed.request.container == fixture.container)
        #expect(parsed.request.scheme == "Kit")
        #expect(parsed.request.configuration == "Release")
        #expect(parsed.request.platforms.isEmpty)
        #expect(parsed.usesDetectedPlatforms)
        #expect(parsed.request.outputDirectory == fixture.outputURL("build"))
        #expect(parsed.request.keepArchives)
        #expect(parsed.request.version == nil)
        #expect(parsed.request.downloadURLTemplate == nil)
        #expect(parsed.request.signingIdentity == nil)
        #expect(parsed.signQuery == nil)
        #expect(parsed.publish == nil)
        #expect(!parsed.printsJSON)
        #expect(!parsed.isVerbose)
    }

    @Test("--platform accepts comma lists and repeats, without duplicates")
    func platformLists() async throws {
        let fixture = try Fixture()

        let parsed = try await fixture.parse(["--project", "Kit.xcodeproj", "--scheme", "Kit",
                                              "--platform", "ios-simulator,ios",
                                              "--platform", "MACOS",
                                              "--platform", "ios,visionos"])

        #expect(parsed.request.platforms == [.iOSSimulator, .iOS, .macOS, .visionOS])
        #expect(parsed.request.orderedPlatforms == [.iOS, .iOSSimulator, .macOS, .visionOS])
        #expect(!parsed.usesDetectedPlatforms)
    }

    @Test("Relative --project and --output paths resolve against the current directory")
    func relativePaths() async throws {
        let fixture = try Fixture()
        try fixture.directory.makeDirectory("Sub/App.xcodeproj")
        let current = fixture.directory.url.appendingPathComponent("Sub", isDirectory: true)

        let parsed = try await BuildArguments(parsing: ["--project", "App.xcodeproj", "--scheme", "App", "--output", "../Out/Here"],
                                              currentDirectory: current)

        #expect(parsed.request.container.url == Fixture.parsedForm(fixture.directory.url.appendingPathComponent("Sub/App.xcodeproj")))
        #expect(parsed.request.container.kind == .project)
        #expect(parsed.request.outputDirectory == fixture.outputURL("Out/Here"))
    }

    @Test("Absolute paths ignore the current directory")
    func absolutePaths() async throws {
        let fixture = try Fixture()

        let parsed = try await BuildArguments(parsing: ["--project", fixture.projectURL.path, "--scheme", "Kit", "--output", "/tmp/fg-out"],
                                              currentDirectory: URL(fileURLWithPath: "/usr"))

        #expect(parsed.request.container == fixture.container)
        #expect(parsed.request.outputDirectory.path == "/tmp/fg-out")
    }

    @Test("--path and --workspace accept a folder and find the workspace in it", arguments: ["--path", "--workspace", "--project"])
    func folderPath(option: String) async throws {
        let fixture = try Fixture(workspace: true)

        let parsed = try await fixture.parse([option, ".", "--scheme", "Kit"])

        #expect(parsed.request.container.kind == .workspace)
        // Folder listings return the /private/var form of the temporary folder, so compare resolved paths.
        #expect(parsed.request.container.url.resolvingSymlinksInPath().path == fixture.projectURL.resolvingSymlinksInPath().path)
        #expect(parsed.request.container.url.lastPathComponent == "Kit.xcworkspace")
    }

    @Test("A project with a sibling workspace builds through the workspace")
    func projectPrefersWorkspace() async throws {
        let fixture = try Fixture(workspace: true)

        let parsed = try await fixture.parse(["--project", "Kit.xcodeproj", "--scheme", "Kit"])

        #expect(parsed.request.container.kind == .workspace)
    }

    @Test("--publish command reads the command and the download URL")
    func publishCommand() async throws {
        let fixture = try Fixture()

        let parsed = try await fixture.parse(["--project", "Kit.xcodeproj", "--scheme", "Kit",
                                              "--publish", "command",
                                              "--publish-command", "scp {path} host:/srv/{zip}",
                                              "--download-url", "https://host/{zip}"])

        #expect(parsed.publish == .command(CommandPublish(commandTemplate: "scp {path} host:/srv/{zip}", downloadURLTemplate: "https://host/{zip}")))
        #expect(parsed.request.downloadURLTemplate == "https://host/{zip}")
    }

    @Test("--publish github uses the default tag and isn't a draft by default")
    func publishGitHubDefaults() async throws {
        let fixture = try Fixture()
        try runGit(["init", "-q"], in: fixture.directory.url)
        try runGit(["remote", "add", "origin", "https://github.com/o/r.git"], in: fixture.directory.url)

        let parsed = try await fixture.parse(["--project", "Kit.xcodeproj", "--scheme", "Kit", "--publish", "github"])

        #expect(parsed.publish == .gitHub(GitHubRelease(remote: GitRemote(host: "github.com", path: "o/r"), tagTemplate: "v{version}", isDraft: false)))
    }

    // MARK: - Errors

    private func expectError(_ expected: CommandLineError, _ arguments: [String], in fixture: Fixture,
                             sourceLocation: SourceLocation = #_sourceLocation) async {
        await #expect(throws: expected, sourceLocation: sourceLocation) {
            _ = try await fixture.parse(arguments)
        }
    }

    @Test("An option without a value throws missingValue")
    func missingValue() async throws {
        let fixture = try Fixture()

        await expectError(.missingValue("--scheme"), ["--project", "Kit.xcodeproj", "--scheme"], in: fixture)
        await expectError(.missingValue("--scheme"), ["--project", "Kit.xcodeproj", "--scheme", "--json"], in: fixture)
        await expectError(.missingValue("--platform"), ["--platform"], in: fixture)
        await expectError(.missingValue("--project"), ["--project"], in: fixture)
    }

    @Test("An unknown option throws unknownOption", arguments: ["--frobnicate", "-v", "Kit", "--Scheme"])
    func unknownOption(option: String) async throws {
        let fixture = try Fixture()

        await expectError(.unknownOption(option), ["--project", "Kit.xcodeproj", option, "Kit"], in: fixture)
    }

    @Test("Missing --project or --scheme throws missingOption")
    func missingOption() async throws {
        let fixture = try Fixture()

        await expectError(.missingOption("--project or --workspace"), ["--scheme", "Kit"], in: fixture)
        await expectError(.missingOption("--project or --workspace"), [], in: fixture)
        await expectError(.missingOption("--scheme"), ["--project", "Kit.xcodeproj"], in: fixture)
    }

    @Test("An unknown platform throws invalidValue with that name")
    func unknownPlatform() async throws {
        let fixture = try Fixture()

        await expectError(.invalidValue(option: "--platform", value: "android"),
                          ["--project", "Kit.xcodeproj", "--scheme", "Kit", "--platform", "ios,android"], in: fixture)
        #expect(CommandLineError.invalidValue(option: "--platform", value: "android").errorDescription?.contains("ios-simulator") == true)
    }

    @Test("A path without a project throws projectNotFound with the given path")
    func projectNotFound() async throws {
        let fixture = try Fixture()
        try fixture.directory.makeDirectory("Empty")

        await expectError(.projectNotFound("Empty"), ["--project", "Empty", "--scheme", "Kit"], in: fixture)
        await expectError(.projectNotFound("Missing"), ["--project", "Missing", "--scheme", "Kit"], in: fixture)
        await expectError(.projectNotFound("Notes.txt"), ["--project", "Notes.txt", "--scheme", "Kit"], in: fixture)
    }

    @Test("A missing .xcodeproj or .xcworkspace path throws projectNotFound",
          arguments: ["Missing.xcodeproj", "Missing.xcworkspace"])
    func missingContainerFile(path: String) async throws {
        let fixture = try Fixture()

        await expectError(.projectNotFound(path), ["--project", path, "--scheme", "Kit"], in: fixture)
    }

    @Test("--publish command requires --publish-command and --download-url")
    func publishCommandRequirements() async throws {
        let fixture = try Fixture()
        let base = ["--project", "Kit.xcodeproj", "--scheme", "Kit", "--publish", "command"]

        await expectError(.missingOption("--publish-command"), base + ["--download-url", "https://host/{zip}"], in: fixture)
        await expectError(.missingOption("--download-url"), base + ["--publish-command", "true"], in: fixture)
        await expectError(.missingOption("--publish-command"), base, in: fixture)
    }

    @Test("An unknown --publish kind throws invalidValue")
    func unknownPublishKind() async throws {
        let fixture = try Fixture()

        await expectError(.invalidValue(option: "--publish", value: "s3"),
                          ["--project", "Kit.xcodeproj", "--scheme", "Kit", "--publish", "s3"], in: fixture)
    }

    @Test("--publish github outside a repository throws invalidValue")
    func publishGitHubWithoutRemote() async throws {
        let fixture = try Fixture()

        await #expect {
            _ = try await fixture.parse(["--project", "Kit.xcodeproj", "--scheme", "Kit", "--publish", "github"])
        } throws: { error in
            guard case let CommandLineError.invalidValue(option, _) = error else { return false }

            return option == "--publish"
        }
    }

}
