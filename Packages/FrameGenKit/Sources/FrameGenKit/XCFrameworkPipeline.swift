//
//  XCFrameworkPipeline.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

public enum StepKind: Equatable, Sendable {
    case archive(Platform)
    case createXCFramework
    case sign
    case package
}

public enum PipelineEvent: Equatable, Sendable {
    /// Sent first, with every step the build will run.
    case planned([StepKind])
    case stepStarted(Int)
    case stepFinished(Int, duration: TimeInterval)
    case stepFailed(Int)
    case log(String)
}

/// A failed step, with the lines of the log that most likely explain why.
public struct PipelineError: LocalizedError {

    public let step: StepKind
    public let underlying: Error
    /// The `error:` lines of the log, or its tail when the tool printed none.
    public let highlights: [String]

    public var errorDescription: String? {
        if case let ProcessError.failed(status, _) = underlying {
            return "The command exited with code \(status)."
        }

        return underlying.localizedDescription
    }

}

/// Archives every platform, creates the XCFramework, optionally signs it, then zips it and
/// computes the SwiftPM checksum. Runs on the caller's actor, so the app can update its UI from `onEvent`.
public enum XCFrameworkPipeline {

    public static func run(_ request: BuildRequest, onEvent: (PipelineEvent) -> Void) async throws -> XCFrameworkBuilder.Summary {
        let platforms = request.orderedPlatforms
        guard !platforms.isEmpty else { throw PipelineConfigurationError.noPlatforms }

        var steps = platforms.map(StepKind.archive) + [.createXCFramework]
        if request.signingIdentity != nil {
            steps.append(.sign)
        }
        steps.append(.package)
        onEvent(.planned(steps))

        var log: [String] = []
        var index = 0

        func record(_ line: String) {
            log.append(line)
            onEvent(.log(line))
        }

        func perform<T>(_ body: () async throws -> T) async throws -> T {
            let start = Date.now
            // Highlights come from this step's output only, so a short codesign or ditto error
            // isn't buried under the archive logs of the steps before it.
            let stepLogStart = log.count
            onEvent(.stepStarted(index))
            do {
                let result = try await body()
                onEvent(.stepFinished(index, duration: Date.now.timeIntervalSince(start)))
                index += 1

                return result
            } catch {
                if error is CancellationError || (error as? ProcessError).map({ if case .canceled = $0 { true } else { false } }) == true {
                    throw error
                }
                onEvent(.stepFailed(index))
                throw PipelineError(step: steps[index], underlying: error, highlights: LogAnalyzer.highlights(in: Array(log[stepLogStart...])))
            }
        }

        func stream(_ runner: ProcessRunner) async throws {
            for try await line in runner.lines() {
                record(line)
            }
            try Task.checkCancellation()
        }

        var archiveURLs: [URL] = []
        for platform in platforms {
            let archiveURL = request.archiveURL(for: platform)
            try await perform {
                try await stream(XcodeCommand.archive(request.container,
                                                      scheme: request.scheme,
                                                      configuration: request.configuration,
                                                      platform: platform,
                                                      archiveURL: archiveURL))
            }
            archiveURLs.append(archiveURL)
        }

        let plan = try await perform {
            let plan = try await XCFrameworkBuilder.makePlan(archiveURLs: archiveURLs, outputDirectoryURL: request.outputDirectory)
            try await stream(XcodeCommand.createXCFramework(slices: plan.slices, output: plan.xcframeworkURL))

            return plan
        }

        if let identity = request.signingIdentity {
            try await perform {
                try await stream(XcodeCommand.sign(plan.xcframeworkURL, identity: identity.sha1))
                try await stream(XcodeCommand.verifySignature(plan.xcframeworkURL))
            }
        }

        let summary = try await perform {
            // The checksum must be computed after signing: signing changes the bundle.
            try await stream(XcodeCommand.zip(source: plan.xcframeworkURL, destination: plan.zipURL))
            let values = Template.Values(name: plan.frameworkName,
                                         version: request.version,
                                         zip: plan.zipURL.lastPathComponent,
                                         path: plan.zipURL.path)
            let downloadURL = try request.downloadURLTemplate.map { try Template($0).url(with: values) }

            return try await XCFrameworkBuilder.finalize(plan, downloadURL: downloadURL, signedBy: request.signingIdentity?.name)
        }

        if !request.keepArchives {
            try? FileManager.default.removeItem(at: request.archivesDirectory)
        }

        return summary
    }

}

public enum PipelineConfigurationError: LocalizedError, Equatable {
    case noPlatforms

    public var errorDescription: String? {
        switch self {
        case .noPlatforms:
            return "Choose at least one platform."
        }
    }
}

public enum LogAnalyzer {

    /// The distinct `error:` lines of a build log, or its last non-empty lines when there are none.
    public static func highlights(in log: [String], limit: Int = 20) -> [String] {
        var seen = Set<String>()
        let errors = log
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("error:") && seen.insert($0).inserted }

        return errors.isEmpty ? Array(log.filter { !$0.isEmpty }.suffix(limit)) : Array(errors.prefix(limit))
    }

}
