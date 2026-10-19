//
//  XcodeCommandTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("xcodebuild, codesign, security and ditto command lines")
struct XcodeCommandTests {

    private let projectURL = URL(fileURLWithPath: "/Users/me/My \"Quoted\" Projects/Kit/Kit.xcodeproj")
    private let workspaceURL = URL(fileURLWithPath: "/Users/me/My \"Quoted\" Projects/Kit/Kit.xcworkspace")

    private var project: ProjectContainer {
        get throws { try #require(ProjectContainer(url: projectURL)) }
    }

    private var workspace: ProjectContainer {
        get throws { try #require(ProjectContainer(url: workspaceURL)) }
    }

    // MARK: - list

    @Test("list asks for JSON about a project and keeps stderr out of it")
    func listProject() throws {
        let runner = XcodeCommand.list(try project)

        #expect(runner.executableURL.path == "/usr/bin/xcodebuild")
        #expect(runner.arguments == ["-list", "-json", "-project", projectURL.path])
        #expect(runner.mergesStandardError == false)
    }

    @Test("list passes a workspace with -workspace")
    func listWorkspace() throws {
        let runner = XcodeCommand.list(try workspace)

        #expect(runner.executableURL.path == "/usr/bin/xcodebuild")
        #expect(runner.arguments == ["-list", "-json", "-workspace", workspaceURL.path])
        #expect(runner.mergesStandardError == false)
    }

    // MARK: - showBuildSettings

    @Test("showBuildSettings asks for the scheme's settings as JSON")
    func showBuildSettingsProject() throws {
        let runner = XcodeCommand.showBuildSettings(try project, scheme: "My Kit")

        #expect(runner.executableURL.path == "/usr/bin/xcodebuild")
        #expect(runner.arguments == ["-showBuildSettings", "-json", "-scheme", "My Kit", "-project", projectURL.path])
        #expect(runner.mergesStandardError == false)
    }

    @Test("showBuildSettings passes a workspace with -workspace")
    func showBuildSettingsWorkspace() throws {
        let runner = XcodeCommand.showBuildSettings(try workspace, scheme: "Kit")

        #expect(runner.arguments == ["-showBuildSettings", "-json", "-scheme", "Kit", "-workspace", workspaceURL.path])
        #expect(runner.mergesStandardError == false)
    }

    // MARK: - archive

    private func expectedArchiveArguments(containerArguments: [String], platform: Platform, archiveURL: URL) -> [String] {
        ["archive"]
            + containerArguments
            + ["-scheme", "My Kit",
               "-configuration", "Release",
               "-destination", platform.destination,
               "-archivePath", archiveURL.path,
               "SKIP_INSTALL=NO",
               "BUILD_LIBRARIES_FOR_DISTRIBUTION=YES",
               "SWIFT_ENABLE_LIBRARY_EVOLUTION=YES",
               "SWIFT_EMIT_MODULE_INTERFACE=YES"]
    }

    @Test("archive passes paths with spaces and quotes as single arguments", arguments: Platform.allCases)
    func archiveProject(platform: Platform) throws {
        let archiveURL = URL(fileURLWithPath: "/Users/me/Out Dir/Archives/My Kit-\(platform.archiveSuffix).xcarchive")
        let runner = XcodeCommand.archive(try project,
                                          scheme: "My Kit",
                                          configuration: "Release",
                                          platform: platform,
                                          archiveURL: archiveURL)

        #expect(runner.executableURL.path == "/usr/bin/xcodebuild")
        #expect(runner.mergesStandardError)
        #expect(runner.arguments == expectedArchiveArguments(containerArguments: ["-project", projectURL.path],
                                                             platform: platform,
                                                             archiveURL: archiveURL))
    }

    @Test("archive builds a workspace with -workspace", arguments: [Platform.iOS, .macCatalyst, .visionOSSimulator])
    func archiveWorkspace(platform: Platform) throws {
        let archiveURL = URL(fileURLWithPath: "/Users/me/Out Dir/Archives/My Kit-\(platform.archiveSuffix).xcarchive")
        let runner = XcodeCommand.archive(try workspace,
                                          scheme: "My Kit",
                                          configuration: "Release",
                                          platform: platform,
                                          archiveURL: archiveURL)

        #expect(runner.arguments == expectedArchiveArguments(containerArguments: ["-workspace", workspaceURL.path],
                                                             platform: platform,
                                                             archiveURL: archiveURL))
        #expect(!runner.arguments.contains("-project"))
    }

    @Test("Mac Catalyst builds for every Mac architecture")
    func catalystDestination() {
        #expect(Platform.macCatalyst.destination == "generic/platform=macOS,variant=Mac Catalyst")
        #expect(!Platform.macCatalyst.destination.contains("arch="))
    }

    // MARK: - createXCFramework

    @Test("create-xcframework lists every framework with its debug symbols")
    func createXCFramework() {
        let first = XCFrameworkBuilder.Slice(frameworkURL: URL(fileURLWithPath: "/a/Kit.framework"),
                                             debugSymbolURLs: [URL(fileURLWithPath: "/a/Kit.framework.dSYM")])
        let second = XCFrameworkBuilder.Slice(frameworkURL: URL(fileURLWithPath: "/b/Kit.framework"),
                                              debugSymbolURLs: [])
        let output = URL(fileURLWithPath: "/out dir/Kit.xcframework")
        let runner = XcodeCommand.createXCFramework(slices: [first, second], output: output)

        #expect(runner.executableURL.path == "/usr/bin/xcodebuild")
        #expect(runner.arguments == ["-create-xcframework",
                                     "-framework", "/a/Kit.framework",
                                     "-debug-symbols", "/a/Kit.framework.dSYM",
                                     "-framework", "/b/Kit.framework",
                                     "-output", "/out dir/Kit.xcframework"])
    }

    // MARK: - Signing

    @Test("sign uses a secure timestamp, replaces an existing signature and passes the identity")
    func sign() {
        let url = URL(fileURLWithPath: "/out dir/Kit.xcframework")
        let identity = "0123456789ABCDEF0123456789ABCDEF01234567"
        let runner = XcodeCommand.sign(url, identity: identity)

        #expect(runner.executableURL.path == "/usr/bin/codesign")
        #expect(runner.arguments == ["--timestamp", "--force", "--sign", identity, "/out dir/Kit.xcframework"])
    }

    @Test("sign passes a certificate name with spaces as one argument")
    func signWithName() {
        let name = "Apple Distribution: Company (TEAMID)"
        let runner = XcodeCommand.sign(URL(fileURLWithPath: "/out/Kit.xcframework"), identity: name)

        #expect(runner.arguments == ["--timestamp", "--force", "--sign", name, "/out/Kit.xcframework"])
    }

    @Test("verifySignature runs a strict codesign verification")
    func verifySignature() {
        let runner = XcodeCommand.verifySignature(URL(fileURLWithPath: "/out dir/Kit.xcframework"))

        #expect(runner.executableURL.path == "/usr/bin/codesign")
        #expect(runner.arguments == ["--verify", "--strict", "--verbose=2", "/out dir/Kit.xcframework"])
    }

    @Test("signingIdentities lists valid code signing identities and keeps stderr out")
    func signingIdentities() {
        let runner = XcodeCommand.signingIdentities()

        #expect(runner.executableURL.path == "/usr/bin/security")
        #expect(runner.arguments == ["find-identity", "-v", "-p", "codesigning"])
        #expect(runner.mergesStandardError == false)
    }

    // MARK: - zip

    @Test("zip keeps the bundle folder and resource forks out of the archive")
    func zip() {
        let runner = XcodeCommand.zip(source: URL(fileURLWithPath: "/out/Kit.xcframework"),
                                      destination: URL(fileURLWithPath: "/out/Kit.xcframework.zip"))

        #expect(runner.executableURL.path == "/usr/bin/ditto")
        #expect(runner.arguments == ["-c", "-k", "--sequesterRsrc", "--keepParent",
                                     "/out/Kit.xcframework", "/out/Kit.xcframework.zip"])
    }

}
