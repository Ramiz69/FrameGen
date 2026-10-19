//
//  ProjectSettingsTests.swift
//  FrameGenTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import FrameGenKit
import Foundation
import Testing
@testable import FrameGen

@Suite("Saved project settings")
struct ProjectSettingsTests {
    
    private func decode(_ json: String) throws -> ProjectSettings {
        try JSONDecoder().decode(ProjectSettings.self, from: Data(json.utf8))
    }
    
    @Test("Settings saved by FrameGen 2.0 still load")
    func readsVersionTwoSettings() throws {
        let settings = try decode(#"""
        {"scheme":"Kit","configuration":"Release","platforms":["iOS","iOSSimulator","macCatalyst"],"outputPath":"/tmp/out"}
        """#)
        
        #expect(settings.scheme == "Kit")
        #expect(settings.configuration == "Release")
        #expect(settings.platforms == [.iOS, .iOSSimulator, .macCatalyst])
        #expect(settings.outputPath == "/tmp/out")
        #expect(settings.distribution == nil)
        #expect(settings.signingIdentity == nil)
    }
    
    @Test("Unknown platforms and fields are skipped instead of failing")
    func toleratesUnknownValues() throws {
        let settings = try decode(#"""
        {"scheme":"Kit","platforms":["iOS","holoOS"],"distribution":"carrierPigeon","futureField":42}
        """#)
        
        #expect(settings.scheme == "Kit")
        #expect(settings.platforms == [.iOS])
        #expect(settings.distribution == nil)
    }
    
    @Test("A settings dictionary with one odd entry keeps every project")
    func dictionarySurvivesBadEntry() throws {
        let data = Data(#"""
        {"/a/A.xcodeproj":{"scheme":"A","platforms":["tvOS"]},"/b/B.xcworkspace":{"scheme":7,"platforms":"iOS"}}
        """#.utf8)
        let all = try JSONDecoder().decode([String: ProjectSettings].self, from: data)
        
        #expect(all["/a/A.xcodeproj"]?.platforms == [.tvOS])
        #expect(all["/b/B.xcworkspace"]?.scheme == nil)
        #expect(all["/b/B.xcworkspace"]?.platforms == nil)
    }
    
    @Test("Settings round-trip through JSON")
    func roundTrip() throws {
        var settings = ProjectSettings()
        settings.scheme = "Kit"
        settings.platforms = [.macOS, .visionOS]
        settings.signingIdentity = SigningIdentity(sha1: String(repeating: "A", count: 40), name: "Apple Distribution: Company")
        settings.distribution = .command
        settings.publishCommand = "aws s3 cp {path} s3://bucket/{zip}"
        settings.downloadURLTemplate = "https://bucket.s3.amazonaws.com/{zip}"
        settings.publishAsDraft = true
        
        let decoded = try JSONDecoder().decode(ProjectSettings.self, from: JSONEncoder().encode(settings))
        
        #expect(decoded == settings)
    }
    
}
