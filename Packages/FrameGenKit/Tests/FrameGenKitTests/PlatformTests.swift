//
//  PlatformTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("Platform slices")
struct PlatformTests {

    struct Expectation: Sendable, CustomTestStringConvertible {
        let platform: Platform
        let cliName: String
        let sdk: String?
        let archiveSuffix: String
        let destination: String
        let family: Platform.Family

        var testDescription: String { platform.rawValue }
    }

    static let expectations: [Expectation] = [
        .init(platform: .iOS, cliName: "ios", sdk: "iphoneos", archiveSuffix: "iphoneos",
              destination: "generic/platform=iOS", family: .iOS),
        .init(platform: .iOSSimulator, cliName: "ios-simulator", sdk: "iphonesimulator", archiveSuffix: "iphonesimulator",
              destination: "generic/platform=iOS Simulator", family: .iOS),
        .init(platform: .macCatalyst, cliName: "maccatalyst", sdk: nil, archiveSuffix: "maccatalyst",
              destination: "generic/platform=macOS,variant=Mac Catalyst", family: .iOS),
        .init(platform: .macOS, cliName: "macos", sdk: "macosx", archiveSuffix: "macosx",
              destination: "generic/platform=macOS", family: .macOS),
        .init(platform: .tvOS, cliName: "tvos", sdk: "appletvos", archiveSuffix: "appletvos",
              destination: "generic/platform=tvOS", family: .tvOS),
        .init(platform: .tvOSSimulator, cliName: "tvos-simulator", sdk: "appletvsimulator", archiveSuffix: "appletvsimulator",
              destination: "generic/platform=tvOS Simulator", family: .tvOS),
        .init(platform: .watchOS, cliName: "watchos", sdk: "watchos", archiveSuffix: "watchos",
              destination: "generic/platform=watchOS", family: .watchOS),
        .init(platform: .watchOSSimulator, cliName: "watchos-simulator", sdk: "watchsimulator", archiveSuffix: "watchsimulator",
              destination: "generic/platform=watchOS Simulator", family: .watchOS),
        .init(platform: .visionOS, cliName: "visionos", sdk: "xros", archiveSuffix: "xros",
              destination: "generic/platform=visionOS", family: .visionOS),
        .init(platform: .visionOSSimulator, cliName: "visionos-simulator", sdk: "xrsimulator", archiveSuffix: "xrsimulator",
              destination: "generic/platform=visionOS Simulator", family: .visionOS),
    ]

    @Test("There are ten platforms and every one has an expectation")
    func allCasesCovered() {
        #expect(Platform.allCases.count == 10)
        #expect(Self.expectations.map(\.platform) == Platform.allCases)
    }

    @Test("Each platform has the expected names, SDK, destination and family", arguments: expectations)
    func properties(_ expectation: Expectation) {
        let platform = expectation.platform

        #expect(platform.cliName == expectation.cliName)
        #expect(platform.sdk == expectation.sdk)
        #expect(platform.archiveSuffix == expectation.archiveSuffix)
        #expect(platform.destination == expectation.destination)
        #expect(platform.family == expectation.family)
        #expect(platform.id == platform.rawValue)
    }

    @Test("init(cliName:) round-trips every platform", arguments: Platform.allCases)
    func cliNameRoundTrip(platform: Platform) {
        #expect(Platform(cliName: platform.cliName) == platform)
    }

    @Test("init(cliName:) ignores case")
    func cliNameIgnoresCase() {
        #expect(Platform(cliName: "iOS") == .iOS)
        #expect(Platform(cliName: "IOS-SIMULATOR") == .iOSSimulator)
        #expect(Platform(cliName: "MacCatalyst") == .macCatalyst)
    }

    @Test("init(cliName:) rejects unknown names", arguments: ["", "iphone", "ios simulator", "mac", "catalyst", "xros", " ios"])
    func cliNameRejectsUnknown(name: String) {
        #expect(Platform(cliName: name) == nil)
    }

    @Test("CLI names, SDKs and archive suffixes are unique")
    func uniqueNames() {
        #expect(Set(Platform.allCases.map(\.cliName)).count == Platform.allCases.count)
        #expect(Set(Platform.allCases.map(\.archiveSuffix)).count == Platform.allCases.count)
        #expect(Set(Platform.allCases.compactMap(\.sdk)).count == Platform.allCases.count - 1)
    }

    @Test("Raw values stay stable because they are persisted")
    func rawValues() throws {
        #expect(Platform.allCases.map(\.rawValue) == ["iOS", "iOSSimulator", "macCatalyst", "macOS", "tvOS", "tvOSSimulator",
                                                       "watchOS", "watchOSSimulator", "visionOS", "visionOSSimulator"])
        let data = try JSONEncoder().encode([Platform.macCatalyst, .visionOSSimulator])
        #expect(String(decoding: data, as: UTF8.self) == #"["macCatalyst","visionOSSimulator"]"#)
        #expect(try JSONDecoder().decode([Platform].self, from: data) == [.macCatalyst, .visionOSSimulator])
    }

    @Test("Every family has at least one platform")
    func everyFamilyUsed() {
        #expect(Set(Platform.allCases.map(\.family)) == Set(Platform.Family.allCases))
    }

}
