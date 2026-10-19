//
//  BuildController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Runs the build pipeline for a project: archive every platform, create the XCFramework,
/// zip it and compute the SwiftPM checksum. Progress is published through `Project.build`.
final class BuildController {

    // MARK: - Properties

    private var task: Task<Void, Never>?

    // MARK: - Public methods

    func start(_ project: Project) {
        guard project.canBuild, let scheme = project.scheme, let configuration = project.configuration else { return }

        let platforms = project.selectedPlatforms
        let state = project.build
        state.start(steps: platforms.map { BuildStep(kind: .archive($0)) }
                    + [BuildStep(kind: .createXCFramework), BuildStep(kind: .package)])
        task = Task {
            await run(project: project.fileURL,
                      scheme: scheme,
                      configuration: configuration,
                      platforms: platforms,
                      outputDirectory: project.outputDirectory,
                      state: state)
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
    }

    // MARK: - Private methods

    private func run(project: URL,
                     scheme: String,
                     configuration: String,
                     platforms: [Platform],
                     outputDirectory: URL,
                     state: BuildState) async {
        let archivesDirectory = outputDirectory.appendingPathComponent("Archives", isDirectory: true)
        var stepIndex = 0
        do {
            var archiveURLs: [URL] = []
            for platform in platforms {
                let archiveURL = archivesDirectory.appendingPathComponent("\(scheme)-\(platform.archiveSuffix).xcarchive")
                try await perform(step: stepIndex, in: state) {
                    try await self.stream(XcodeCommand.archive(project: project,
                                                               scheme: scheme,
                                                               configuration: configuration,
                                                               platform: platform,
                                                               archiveURL: archiveURL),
                                          into: state)
                }
                archiveURLs.append(archiveURL)
                stepIndex += 1
            }

            let plan = try await perform(step: stepIndex, in: state) {
                let plan = try await XCFrameworkBuilder.makePlan(archiveURLs: archiveURLs, outputDirectoryURL: outputDirectory)
                try await self.stream(XcodeCommand.createXCFramework(slices: plan.slices, output: plan.xcframeworkURL), into: state)

                return plan
            }
            stepIndex += 1

            let summary = try await perform(step: stepIndex, in: state) {
                try await self.stream(XcodeCommand.zip(source: plan.xcframeworkURL, destination: plan.zipURL), into: state)

                return try await XCFrameworkBuilder.finalize(plan)
            }

            if !Preferences.keepArchives {
                try? FileManager.default.removeItem(at: archivesDirectory)
            }
            state.finish(.succeeded(summary))
            if Preferences.revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([summary.plan.xcframeworkURL])
            }
        } catch is CancellationError {
            state.reset()
        } catch ProcessError.canceled {
            state.reset()
        } catch {
            state.finish(.failed(Self.failure(for: error, step: state.steps[stepIndex], log: state.log)))
        }
        NSApp.requestUserAttention(.informationalRequest)
    }

    private func perform<T>(step index: Int, in state: BuildState, _ body: () async throws -> T) async throws -> T {
        let start = Date.now
        state.steps[index].status = .running(since: start)
        do {
            let result = try await body()
            state.steps[index].status = .succeeded(duration: Date.now.timeIntervalSince(start))

            return result
        } catch {
            state.steps[index].status = Task.isCancelled ? .pending : .failed
            throw error
        }
    }

    private func stream(_ runner: ProcessRunner, into state: BuildState) async throws {
        for try await line in runner.lines() {
            state.appendLog(line)
        }
        try Task.checkCancellation()
    }

    private static func failure(for error: Error, step: BuildStep, log: [String]) -> BuildFailure {
        let reason: String
        if case let ProcessError.failed(status, _) = error {
            reason = "The command exited with code \(status). See the highlighted lines below or the full log."
        } else {
            reason = error.localizedDescription
        }

        var seen = Set<String>()
        let errors = log
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("error:") && seen.insert($0).inserted }
        let highlights = errors.isEmpty ? log.suffix(20).filter { !$0.isEmpty } : Array(errors.prefix(20))

        return BuildFailure(title: step.failureTitle, reason: reason, highlights: highlights)
    }

}
