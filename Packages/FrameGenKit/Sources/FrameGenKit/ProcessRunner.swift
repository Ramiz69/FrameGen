//
//  ProcessRunner.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

public enum ProcessError: Error {
    case failed(status: Int32, output: String)
    case canceled
}

extension ProcessError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case let .failed(status, _):
            return "The command exited with code \(status)."
        case .canceled:
            return "The operation was canceled."
        }
    }

}

/// Runs a command-line tool. Arguments are passed as an array, so paths never need shell escaping.
public struct ProcessRunner: Sendable {

    // MARK: - Properties

    public let executableURL: URL
    public var arguments: [String]
    /// When `true`, stderr is interleaved with stdout, which keeps build logs in their natural order.
    /// Disable it for commands whose stdout must stay machine-readable, like `xcodebuild -list -json`.
    public var mergesStandardError: Bool
    /// Replaces the inherited environment when set. GUI apps start with a minimal `PATH`,
    /// so tools like `gh` that call other tools need one; see `ProcessRunner.toolEnvironment(adding:)`.
    public var environment: [String: String]?

    // MARK: - Initial methods

    public init(executableURL: URL,
                arguments: [String] = [],
                mergesStandardError: Bool = true,
                environment: [String: String]? = nil) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.mergesStandardError = mergesStandardError
        self.environment = environment
    }

    /// The current environment with Homebrew's and the system's tool folders on `PATH`.
    public static func toolEnvironment(adding variables: [String: String] = [:]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let standardPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let currentPaths = environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        environment["PATH"] = (currentPaths + standardPaths.filter { !currentPaths.contains($0) }).joined(separator: ":")
        environment.merge(variables) { _, new in new }

        return environment
    }

    /// Finds an executable by name in the folders of `toolEnvironment(adding:)`'s `PATH`.
    public static func findTool(named name: String) -> URL? {
        let paths = toolEnvironment()["PATH"]?.split(separator: ":") ?? []

        return paths
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    // MARK: - Public methods

    /// Streams the output line by line. Cancelling the consuming task interrupts the process,
    /// the same way Ctrl-C does in Terminal.
    public func lines() -> AsyncThrowingStream<String, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        let task = Task {
            do {
                _ = try await execute { continuation.yield($0) }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }

        return stream
    }

    /// Runs the process to completion and returns its stdout.
    @concurrent
    public func output() async throws -> String {
        try await execute { _ in }
    }

    // MARK: - Private methods

    @concurrent
    private func execute(onLine: @escaping @Sendable (String) -> Void) async throws -> String {
        try Task.checkCancellation()

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let environment {
            process.environment = environment
        }
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = mergesStandardError ? outputPipe : errorPipe

        let (exit, exitContinuation) = AsyncStream.makeStream(of: Never.self)
        process.terminationHandler = { _ in exitContinuation.finish() }
        try process.run()
        let control = ProcessControl(process: process)

        return try await withTaskCancellationHandler {
            // Both pipes are read at the same time: a pipe nobody reads blocks the process once its buffer fills.
            async let errorOutput = mergesStandardError ? "" : Self.readAll(errorPipe.fileHandleForReading)
            var output = ""
            do {
                for try await line in outputPipe.fileHandleForReading.bytes.lines {
                    output += line + "\n"
                    onLine(line)
                }
            } catch is CancellationError {
                // The process was interrupted; wait for it to exit below.
            }
            for await _ in exit {}
            let errors = await errorOutput

            if control.isCanceled || process.terminationReason == .uncaughtSignal {
                throw ProcessError.canceled
            }
            guard process.terminationStatus == .zero else {
                throw ProcessError.failed(status: process.terminationStatus, output: output + errors)
            }

            return output
        } onCancel: {
            control.interrupt()
        }
    }

    @concurrent
    private static func readAll(_ handle: FileHandle) async -> String {
        var data = Data()
        do {
            for try await byte in handle.bytes {
                data.append(byte)
            }
        } catch {
            // Whatever was read before the failure is still useful for the error message.
        }

        return String(decoding: data, as: UTF8.self)
    }

}

/// Lets the cancellation handler, which runs on an arbitrary thread, interrupt the process.
nonisolated private final class ProcessControl: @unchecked Sendable {

    private let lock = NSLock()
    private let process: Process
    private var canceled = false

    init(process: Process) {
        self.process = process
    }

    var isCanceled: Bool {
        lock.withLock { canceled }
    }

    func interrupt() {
        lock.withLock {
            canceled = true
            // xcodebuild handles SIGINT gracefully and stops the whole build, including its child compilers.
            if process.isRunning {
                process.interrupt()
            }
        }
    }

}
