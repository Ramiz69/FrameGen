//
//  BuildController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit
import FrameGenKit

/// Runs `XCFrameworkPipeline` for a project and mirrors its events into `Project.build`,
/// then publishes the result on request. The same pipeline powers the `framegen` tool.
final class BuildController {

    // MARK: - Properties

    private var task: Task<Void, Never>?
    private var publishTask: Task<Void, Never>?
    private let notifier = BuildNotifier()

    // MARK: - Public methods

    func start(_ project: Project) {
        guard project.canBuild, let request = project.makeBuildRequest() else { return }

        let state = project.build
        state.start(steps: [])
        notifier.requestAuthorizationIfNeeded()
        task = Task {
            await run(request, projectName: project.name, state: state)
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
        publishTask?.cancel()
    }

    func publish(_ project: Project) {
        guard
            case .succeeded(let summary) = project.build.phase,
            let destination = project.publishDestination,
            project.build.publishState != .publishing
        else {
            return
        }

        let state = project.build
        let version = project.version
        state.publishState = .publishing
        publishTask = Task {
            do {
                let url = try await Publisher.publish(summary, version: version, to: destination) { state.appendLog($0) }
                let updated = try summary.withDownloadURL(url)
                state.finish(.succeeded(updated))
                state.publishState = .published(url)
            } catch is CancellationError {
                state.publishState = .idle
            } catch ProcessError.canceled {
                state.publishState = .idle
            } catch let ProcessError.failed(_, output) {
                state.publishState = .failed(LogAnalyzer.highlights(in: output.components(separatedBy: .newlines), limit: 5)
                    .joined(separator: "\n"))
            } catch {
                state.publishState = .failed(error.localizedDescription)
            }
            publishTask = nil
        }
    }

    // MARK: - Private methods

    private func run(_ request: BuildRequest, projectName: String, state: BuildState) async {
        do {
            let summary = try await XCFrameworkPipeline.run(request) { event in
                switch event {
                case .planned(let steps):
                    state.steps = steps.map { BuildStep(kind: $0) }
                case .stepStarted(let index):
                    state.steps[index].status = .running(since: .now)
                case let .stepFinished(index, duration):
                    state.steps[index].status = .succeeded(duration: duration)
                case .stepFailed(let index):
                    state.steps[index].status = .failed
                case .log(let line):
                    state.appendLog(line)
                }
            }
            state.finish(.succeeded(summary))
            notifier.notify(.succeeded(projectName: projectName, frameworkName: summary.plan.frameworkName))
            if Preferences.revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([summary.plan.xcframeworkURL])
            }
        } catch is CancellationError {
            state.reset()
        } catch ProcessError.canceled {
            state.reset()
        } catch let error as PipelineError {
            let step = BuildStep(kind: error.step)
            let reason: String
            if case let ProcessError.failed(status, _) = error.underlying {
                reason = String(localized: "The command exited with code \(status). See the highlighted lines below or the full log.")
            } else {
                reason = error.underlying.localizedDescription
            }
            state.finish(.failed(BuildFailure(title: step.failureTitle, reason: reason, highlights: error.highlights)))
            notifier.notify(.failed(projectName: projectName, title: step.failureTitle))
        } catch {
            state.finish(.failed(BuildFailure(title: String(localized: "The build couldn’t start"),
                                              reason: error.localizedDescription,
                                              highlights: [])))
        }
        NSApp.requestUserAttention(.informationalRequest)
    }

}
