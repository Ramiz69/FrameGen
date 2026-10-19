//
//  PipelineTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("XCFramework pipeline configuration")
struct PipelineTests {

    @Test("run throws noPlatforms for an empty platform list before running or reporting anything")
    func noPlatforms() async throws {
        let directory = try TemporaryDirectory()
        let container = try #require(ProjectContainer(url: directory.url.appendingPathComponent("Kit.xcodeproj")))
        let request = BuildRequest(container: container,
                                   scheme: "Kit",
                                   platforms: [],
                                   outputDirectory: directory.url.appendingPathComponent("Output"))
        var events: [PipelineEvent] = []

        await #expect(throws: PipelineConfigurationError.noPlatforms) {
            _ = try await XCFrameworkPipeline.run(request) { events.append($0) }
        }

        #expect(events.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: request.outputDirectory.path))
        #expect(!FileManager.default.fileExists(atPath: request.archivesDirectory.path))
    }

    @Test("noPlatforms asks the user to choose a platform")
    func noPlatformsDescription() {
        #expect(PipelineConfigurationError.noPlatforms.errorDescription == "Choose at least one platform.")
    }

}
