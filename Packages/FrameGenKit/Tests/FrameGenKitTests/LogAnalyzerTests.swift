//
//  LogAnalyzerTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("Picking the interesting lines of a build log")
struct LogAnalyzerTests {

    @Test("Returns the distinct error: lines, trimmed, in order")
    func errorLines() {
        let log = [
            "Build settings from command line:",
            "    SKIP_INSTALL = NO",
            "/Users/me/Kit/Sources/A.swift:12:5: error: cannot find 'foo' in scope",
            "        foo()",
            "/Users/me/Kit/Sources/B.swift:3:1: warning: unused variable",
            "  /Users/me/Kit/Sources/A.swift:12:5: error: cannot find 'foo' in scope  ",
            "error: Signing for \"Kit\" requires a development team.",
            "** ARCHIVE FAILED **",
        ]

        #expect(LogAnalyzer.highlights(in: log) == [
            "/Users/me/Kit/Sources/A.swift:12:5: error: cannot find 'foo' in scope",
            "error: Signing for \"Kit\" requires a development team.",
        ])
    }

    @Test("Without errors, returns the last non-empty lines")
    func tailWithoutErrors() {
        let log = (1...30).map { "line \($0)" } + ["", ""]

        let highlights = LogAnalyzer.highlights(in: log)

        #expect(highlights == (11...30).map { "line \($0)" })
    }

    @Test("The limit caps both errors and the tail")
    func limit() {
        let errors = (1...10).map { "error: problem \($0)" }
        let plain = (1...10).map { "line \($0)" }

        #expect(LogAnalyzer.highlights(in: errors, limit: 3) == ["error: problem 1", "error: problem 2", "error: problem 3"])
        #expect(LogAnalyzer.highlights(in: plain, limit: 3) == ["line 8", "line 9", "line 10"])
    }

    @Test("A short log without errors is returned whole, minus empty lines")
    func shortLog() {
        #expect(LogAnalyzer.highlights(in: ["a", "", "b"]) == ["a", "b"])
    }

    @Test("An empty log has no highlights")
    func emptyLog() {
        #expect(LogAnalyzer.highlights(in: []).isEmpty)
        #expect(LogAnalyzer.highlights(in: ["", ""]).isEmpty)
    }

    @Test("Lines that mention errors without error: aren't errors")
    func onlyErrorColon() {
        let log = ["0 errors generated", "Error Domain=foo", "fatal error: boom"]

        #expect(LogAnalyzer.highlights(in: log) == ["fatal error: boom"])
    }

}
