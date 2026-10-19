//
//  XcodeCommandTests.swift
//  FrameGenTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGen

@Suite("xcodebuild and ditto command lines")
struct XcodeCommandTests {

    private let project = URL(fileURLWithPath: "/Users/me/My \"Quoted\" Projects/Kit/Kit.xcodeproj")

    @Test("list asks for JSON and keeps stderr out of it")
    func list() {
        let runner = XcodeCommand.list(project: project)

        #expect(runner.executableURL.path == "/usr/bin/xcodebuild")
        #expect(runner.arguments == ["-list", "-json", "-project", project.path])
        #expect(runner.mergesStandardError == false)
    }

    @Test("archive passes paths with spaces and quotes as single arguments", arguments: Platform.allCases)
    func archive(platform: Platform) {
        let archiveURL = URL(fileURLWithPath: "/Users/me/Out Dir/Archives/My Kit-\(platform.archiveSuffix).xcarchive")
        let runner = XcodeCommand.archive(project: project,
                                          scheme: "My Kit",
                                          configuration: "Release",
                                          platform: platform,
                                          archiveURL: archiveURL)

        #expect(runner.executableURL.path == "/usr/bin/xcodebuild")
        #expect(runner.mergesStandardError)
        #expect(runner.arguments == ["archive",
                                     "-project", project.path,
                                     "-scheme", "My Kit",
                                     "-configuration", "Release",
                                     "-destination", platform.destination,
                                     "-archivePath", archiveURL.path,
                                     "SKIP_INSTALL=NO",
                                     "BUILD_LIBRARIES_FOR_DISTRIBUTION=YES",
                                     "SWIFT_ENABLE_LIBRARY_EVOLUTION=YES",
                                     "SWIFT_EMIT_MODULE_INTERFACE=YES"])
    }

    @Test("Mac Catalyst builds for every Mac architecture")
    func catalystDestination() {
        #expect(Platform.macCatalyst.destination == "generic/platform=macOS,variant=Mac Catalyst")
        #expect(!Platform.macCatalyst.destination.contains("arch="))
    }

    @Test("create-xcframework lists every framework with its debug symbols")
    func createXCFramework() {
        let first = XCFrameworkBuilder.Slice(frameworkURL: URL(fileURLWithPath: "/a/Kit.framework"),
                                             debugSymbolURLs: [URL(fileURLWithPath: "/a/Kit.framework.dSYM")])
        let second = XCFrameworkBuilder.Slice(frameworkURL: URL(fileURLWithPath: "/b/Kit.framework"),
                                              debugSymbolURLs: [])
        let output = URL(fileURLWithPath: "/out dir/Kit.xcframework")
        let runner = XcodeCommand.createXCFramework(slices: [first, second], output: output)

        #expect(runner.arguments == ["-create-xcframework",
                                     "-framework", "/a/Kit.framework",
                                     "-debug-symbols", "/a/Kit.framework.dSYM",
                                     "-framework", "/b/Kit.framework",
                                     "-output", "/out dir/Kit.xcframework"])
    }

    @Test("zip keeps the bundle folder and resource forks out of the archive")
    func zip() {
        let runner = XcodeCommand.zip(source: URL(fileURLWithPath: "/out/Kit.xcframework"),
                                      destination: URL(fileURLWithPath: "/out/Kit.xcframework.zip"))

        #expect(runner.executableURL.path == "/usr/bin/ditto")
        #expect(runner.arguments == ["-c", "-k", "--sequesterRsrc", "--keepParent",
                                     "/out/Kit.xcframework", "/out/Kit.xcframework.zip"])
    }

}
