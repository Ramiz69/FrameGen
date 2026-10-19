//
//  BuildState.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Observation

struct BuildStep: Identifiable {

    enum Kind: Equatable {
        case archive(Platform)
        case createXCFramework
        case package
    }

    enum Status: Equatable {
        case pending
        case running(since: Date)
        case succeeded(duration: TimeInterval)
        case failed
    }

    let kind: Kind
    var status: Status = .pending

    var id: String { title }

    var title: String {
        switch kind {
        case .archive(let platform):
            return "Archive for \(platform.title)"
        case .createXCFramework:
            return "Create XCFramework"
        case .package:
            return "Zip and compute checksum"
        }
    }

    var failureTitle: String {
        switch kind {
        case .archive(let platform):
            return "Archiving for \(platform.title) failed"
        case .createXCFramework:
            return "Creating the XCFramework failed"
        case .package:
            return "Packaging the XCFramework failed"
        }
    }
}

struct BuildFailure {
    let title: String
    let reason: String
    /// The `error:` lines of the log, or its tail when the tool printed none.
    let highlights: [String]
}

/// The progress and outcome of one XCFramework build.
@Observable
final class BuildState {

    enum Phase {
        case idle
        case running
        case succeeded(XCFrameworkBuilder.Summary)
        case failed(BuildFailure)
    }

    // MARK: - Properties

    var phase: Phase = .idle
    var steps: [BuildStep] = []
    /// The most recent xcodebuild action, e.g. "SwiftCompile normal arm64 Compiling Kit.swift".
    var activity = ""
    private(set) var log: [String] = []
    private(set) var startDate: Date?
    private(set) var endDate: Date?

    var isRunning: Bool {
        if case .running = phase { return true }

        return false
    }

    var duration: TimeInterval {
        guard let startDate else { return .zero }

        return (endDate ?? .now).timeIntervalSince(startDate)
    }

    // MARK: - Public methods

    func start(steps: [BuildStep]) {
        self.steps = steps
        log = []
        activity = "Preparing…"
        startDate = .now
        endDate = nil
        phase = .running
    }

    func finish(_ phase: Phase) {
        endDate = .now
        activity = ""
        self.phase = phase
    }

    func reset() {
        steps = []
        log = []
        activity = ""
        startDate = nil
        endDate = nil
        phase = .idle
    }

    func appendLog(_ line: String) {
        log.append(line)
        if let action = Self.action(from: line) {
            activity = action
        }
    }

    // MARK: - Private methods

    /// xcodebuild prints every build action as `Action arguments (in target 'X' from project 'Y')`.
    private static func action(from line: String) -> String? {
        guard
            let first = line.first, first.isUppercase,
            let range = line.range(of: " (in target ")
        else {
            return nil
        }

        return String(line[..<range.lowerBound]).replacingOccurrences(of: "\\ ", with: " ")
    }

}
