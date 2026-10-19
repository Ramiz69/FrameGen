//
//  BuildRequestTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("Build requests and project containers")
struct BuildRequestTests {

    private func request(platforms: [Platform], scheme: String = "Kit") throws -> BuildRequest {
        let container = try #require(ProjectContainer(url: URL(fileURLWithPath: "/Users/me/Kit/Kit.xcodeproj")))

        return BuildRequest(container: container,
                            scheme: scheme,
                            platforms: platforms,
                            outputDirectory: URL(fileURLWithPath: "/Users/me/Build Output", isDirectory: true))
    }

    // MARK: - BuildRequest

    @Test("Defaults: Release, unsigned, archives kept, no version or download URL")
    func defaults() throws {
        let request = try request(platforms: [.iOS])

        #expect(request.configuration == "Release")
        #expect(request.signingIdentity == nil)
        #expect(request.keepArchives)
        #expect(request.version == nil)
        #expect(request.downloadURLTemplate == nil)
    }

    @Test("orderedPlatforms removes duplicates and follows Platform.allCases")
    func orderedPlatforms() throws {
        let request = try request(platforms: [.visionOS, .iOSSimulator, .macOS, .iOS, .iOSSimulator, .macCatalyst, .visionOS])

        #expect(request.orderedPlatforms == [.iOS, .iOSSimulator, .macCatalyst, .macOS, .visionOS])
        #expect(request.platforms.count == 7)
    }

    @Test("orderedPlatforms is empty without platforms")
    func orderedPlatformsEmpty() throws {
        #expect(try request(platforms: []).orderedPlatforms.isEmpty)
    }

    @Test("orderedPlatforms of every platform is Platform.allCases")
    func orderedPlatformsAll() throws {
        #expect(try request(platforms: Platform.allCases.reversed()).orderedPlatforms == Platform.allCases)
    }

    @Test("Archives go to the Archives folder of the output directory")
    func archivesDirectory() throws {
        #expect(try request(platforms: [.iOS]).archivesDirectory.path == "/Users/me/Build Output/Archives")
    }

    @Test("Each platform gets its own archive named after the scheme and SDK", arguments: Platform.allCases)
    func archiveURL(platform: Platform) throws {
        let request = try request(platforms: [platform], scheme: "My Kit")

        let url = request.archiveURL(for: platform)

        #expect(url.path == "/Users/me/Build Output/Archives/My Kit-\(platform.archiveSuffix).xcarchive")
    }

    @Test("Archive URLs are unique per platform")
    func archiveURLsUnique() throws {
        let request = try request(platforms: Platform.allCases)

        #expect(Set(Platform.allCases.map { request.archiveURL(for: $0) }).count == Platform.allCases.count)
    }

    // MARK: - ProjectContainer

    @Test("A project container passes -project")
    func projectContainer() throws {
        let container = try #require(ProjectContainer(url: URL(fileURLWithPath: "/Users/me/My Kit/My Kit.xcodeproj")))

        #expect(container.kind == .project)
        #expect(container.name == "My Kit")
        #expect(container.directoryURL.path == "/Users/me/My Kit")
        #expect(container.xcodebuildArguments == ["-project", "/Users/me/My Kit/My Kit.xcodeproj"])
    }

    @Test("A workspace container passes -workspace")
    func workspaceContainer() throws {
        let container = try #require(ProjectContainer(url: URL(fileURLWithPath: "/Users/me/App/App.xcworkspace")))

        #expect(container.kind == .workspace)
        #expect(container.name == "App")
        #expect(container.directoryURL.path == "/Users/me/App")
        #expect(container.xcodebuildArguments == ["-workspace", "/Users/me/App/App.xcworkspace"])
    }

    @Test("Other paths aren't containers", arguments: ["/Users/me/Kit", "/Users/me/Package.swift", "/Users/me/Kit.xcodeproj.zip", "/Users/me/Kit.playground"])
    func notContainers(path: String) {
        #expect(ProjectContainer(url: URL(fileURLWithPath: path)) == nil)
    }

}
