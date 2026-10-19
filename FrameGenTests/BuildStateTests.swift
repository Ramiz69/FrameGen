//
//  BuildStateTests.swift
//  FrameGenTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGen

@MainActor
@Suite("Build progress state")
struct BuildStateTests {

    @Test("The current action comes from xcodebuild action lines")
    func extractsActivity() {
        let state = BuildState()
        state.start(steps: [BuildStep(kind: .archive(.iOS))])

        state.appendLog("SwiftCompile normal arm64 Compiling\\ Kit.swift /src/My\\ Kit/Kit.swift (in target 'Kit' from project 'Kit')")

        #expect(state.activity == "SwiftCompile normal arm64 Compiling Kit.swift /src/My Kit/Kit.swift")
        #expect(state.log.count == 1)
    }

    @Test("Other lines are logged but keep the previous action", arguments: [
        "    cd /Users/me/Kit",
        "/src/Kit.swift:3:1: error: expected declaration (in target 'Kit' from project 'Kit')",
        "** ARCHIVE SUCCEEDED **",
        "",
    ])
    func ignoresOtherLines(line: String) {
        let state = BuildState()
        state.start(steps: [])
        state.appendLog("Ld /build/Kit normal (in target 'Kit' from project 'Kit')")

        state.appendLog(line)

        #expect(state.activity == "Ld /build/Kit normal")
        #expect(state.log.last == line)
    }

    @Test("Starting a build resets the previous one")
    func startResets() {
        let state = BuildState()
        state.start(steps: [BuildStep(kind: .archive(.iOS))])
        state.appendLog("old line")
        state.finish(.idle)

        state.start(steps: [BuildStep(kind: .createXCFramework), BuildStep(kind: .package)])

        #expect(state.isRunning)
        #expect(state.log.isEmpty)
        #expect(state.steps.map(\.kind) == [.createXCFramework, .package])
        #expect(state.steps.allSatisfy { $0.status == .pending })
    }

    @Test("Reset returns to idle")
    func reset() {
        let state = BuildState()
        state.start(steps: [BuildStep(kind: .package)])
        state.appendLog("line")

        state.reset()

        #expect(!state.isRunning)
        #expect(state.steps.isEmpty)
        #expect(state.log.isEmpty)
        #expect(state.duration == .zero)
    }

    @Test("Step titles name the platform")
    func stepTitles() {
        #expect(BuildStep(kind: .archive(.iOSSimulator)).title == "Archive for iOS Simulator")
        #expect(BuildStep(kind: .archive(.macCatalyst)).failureTitle == "Archiving for Mac Catalyst failed")
    }

}
