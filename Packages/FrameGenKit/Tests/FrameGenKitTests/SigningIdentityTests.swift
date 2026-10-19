//
//  SigningIdentityTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("Reading security find-identity output")
struct SigningIdentityTests {

    private let distribution = "0123456789ABCDEF0123456789ABCDEF01234567"
    private let developerID = "89ABCDEF0123456789ABCDEF0123456789abcdef"
    private let development = "FEDCBA9876543210FEDCBA9876543210FEDCBA98"

    @Test("Parses every identity in order and ignores the summary line")
    func parsesIdentities() {
        let output = """
          1) \(distribution) "Apple Distribution: Company Name (TEAMID1234)"
          2) \(developerID) "Developer ID Application: Ramiz Kichibekov (ABCDE12345)"
          3) \(development) "Apple Development: me@example.com (XYZ9876543)"
             3 valid identities found

        """

        let identities = SigningIdentity.parse(output)

        #expect(identities == [
            SigningIdentity(sha1: distribution, name: "Apple Distribution: Company Name (TEAMID1234)"),
            SigningIdentity(sha1: developerID, name: "Developer ID Application: Ramiz Kichibekov (ABCDE12345)"),
            SigningIdentity(sha1: development, name: "Apple Development: me@example.com (XYZ9876543)"),
        ])
    }

    @Test("Deduplicates identities by SHA-1 and keeps renewed certificates with the same name")
    func deduplicates() {
        let output = """
          1) \(distribution) "Apple Distribution: Company (TEAMID)"
          2) \(development) "Apple Distribution: Company (TEAMID)"
          3) \(distribution) "Apple Distribution: Company (TEAMID)"
             3 valid identities found
        """

        let identities = SigningIdentity.parse(output)

        #expect(identities.map(\.sha1) == [distribution, development])
        #expect(identities.map(\.name) == ["Apple Distribution: Company (TEAMID)", "Apple Distribution: Company (TEAMID)"])
    }

    @Test("No identities gives an empty list", arguments: ["", "     0 valid identities found\n"])
    func empty(output: String) {
        #expect(SigningIdentity.parse(output).isEmpty)
    }

    @Test("Malformed lines are skipped", arguments: [
        // Hash too short.
        #"  1) 0123456789ABCDEF "Apple Distribution: Company""#,
        // Not hexadecimal.
        #"  1) ZZZZ456789ABCDEF0123456789ABCDEF01234567 "Apple Distribution: Company""#,
        // Name not quoted.
        "  1) 0123456789ABCDEF0123456789ABCDEF01234567 Apple Distribution",
        // Empty name.
        #"  1) 0123456789ABCDEF0123456789ABCDEF01234567 """#,
        // No index.
        #"0123456789ABCDEF0123456789ABCDEF01234567 "Apple Distribution: Company""#,
        // No name.
        "  1) 0123456789ABCDEF0123456789ABCDEF01234567",
        "Policy: Code Signing",
        "  Matching identities",
    ])
    func skipsMalformedLines(line: String) {
        #expect(SigningIdentity.parse(line).isEmpty)
    }

    @Test("Valid identities next to malformed lines are still found")
    func mixedOutput() {
        let output = """
        Policy: Code Signing
          Matching identities
          1) 0123 "Broken"
          2) \(developerID) "Developer ID Application: Me (TEAM)"
             1 valid identities found
        """

        #expect(SigningIdentity.parse(output) == [SigningIdentity(sha1: developerID, name: "Developer ID Application: Me (TEAM)")])
    }

    @Test("Two-digit indexes and quotes inside names are kept")
    func longIndexAndQuotes() {
        let output = #"  12) \#(distribution) "Apple Distribution: "Quoted" Co (TEAM)""#

        #expect(SigningIdentity.parse(output) == [SigningIdentity(sha1: distribution, name: #"Apple Distribution: "Quoted" Co (TEAM)"#)])
    }

    @Test("The id is the SHA-1")
    func identifier() {
        #expect(SigningIdentity(sha1: distribution, name: "A").id == distribution)
    }

}
