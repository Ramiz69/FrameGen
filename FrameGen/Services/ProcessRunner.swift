//
//  ProcessRunner.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

nonisolated enum ProcessError: Error {
    case failed(status: Int32, output: String)
    case canceled
}

extension ProcessError: LocalizedError {

    nonisolated var errorDescription: String? {
        switch self {
        case let .failed(status, _):
            return "The command exited with code \(status)."
        case .canceled:
            return "The operation was canceled."
        }
    }

}

/// Runs a command-line tool. Arguments are passed as an array, so paths never need shell escaping.
nonisolated struct ProcessRunner: Sendable {

    // MARK: - Properties

    let executableURL: URL
    var arguments: [String] = []
    /// When `true`, stderr is interleaved with stdout, which keeps build logs in their natural order.
    /// Disable it for commands whose stdout must stay machine-readable, like `xcodebuild -list -json`.
    var mergesStandardError = true

    // MARK: - Public methods

    /// Streams the output line by line. Cancelling the consuming task interrupts the process,
    /// the same way Ctrl-C does in Terminal.
    func lines() -> AsyncThrowingStream<String, any Error> {
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
    func output() async throws -> String {
        try await execute { _ in }
    }

    // MARK: - Private methods

    @concurrent
    private func execute(onLine: @escaping @Sendable (String) -> Void) async throws -> String {
        try Task.checkCancellation()

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
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
