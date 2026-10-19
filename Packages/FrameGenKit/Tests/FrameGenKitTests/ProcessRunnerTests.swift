//
//  ProcessRunnerTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Testing
import Foundation
@testable import FrameGenKit

@Suite struct ProcessRunnerTests {

    // MARK: - Helpers

    private func shell(_ script: String, mergesStandardError: Bool = true) -> ProcessRunner {
        ProcessRunner(executableURL: URL(fileURLWithPath: "/bin/sh"),
                      arguments: ["-c", script],
                      mergesStandardError: mergesStandardError)
    }

    // MARK: - Tests

    @Test("output returns the command's stdout")
    func outputReturnsStandardOutput() async throws {
        let output = try await shell(#"printf 'a\nb\n'"#).output()

        #expect(output == "a\nb\n")
    }

    @Test("lines yields every line in order")
    func linesYieldsLinesInOrder() async throws {
        var lines: [String] = []
        for try await line in shell(#"printf 'one\ntwo\nthree\n'"#).lines() {
            lines.append(line)
        }

        #expect(lines == ["one", "two", "three"])
    }

    @Test("A non-zero exit throws failed with the status and the output")
    func nonZeroExitThrowsFailed() async throws {
        await #expect {
            _ = try await shell("echo boom; exit 3").output()
        } throws: { error in
            guard case let ProcessError.failed(status, output) = error else {
                return false
            }

            return status == 3 && output.contains("boom")
        }
    }

    @Test("Merged stderr is included in the failure output")
    func mergedStandardErrorIsInFailureOutput() async throws {
        await #expect {
            _ = try await shell("echo oops >&2; exit 1").output()
        } throws: { error in
            guard case let ProcessError.failed(status, output) = error else {
                return false
            }

            return status == 1 && output.contains("oops")
        }
    }

    @Test("Separate stderr is kept out of the returned stdout")
    func separateStandardErrorIsNotInOutput() async throws {
        let output = try await shell("echo out; echo err >&2", mergesStandardError: false).output()

        #expect(output == "out\n")
        #expect(!output.contains("err"))
    }

    @Test("Cancelling the task interrupts the process and throws canceled", .timeLimit(.minutes(1)))
    func cancellationThrowsCanceled() async throws {
        let runner = shell("exec sleep 30")
        let task = Task { try await runner.output() }
        try await Task.sleep(for: .milliseconds(500))
        task.cancel()

        await #expect {
            _ = try await task.value
        } throws: { error in
            guard case ProcessError.canceled = error else {
                return false
            }

            return true
        }
    }

    @Test("Running a missing executable throws")
    func missingExecutableThrows() async throws {
        let runner = ProcessRunner(executableURL: URL(fileURLWithPath: "/nonexistent/tool"))

        await #expect(throws: (any Error).self) {
            _ = try await runner.output()
        }
    }

}
