//
//  SigningIdentity.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// A code signing certificate with its private key, as listed by `security find-identity`.
public struct SigningIdentity: Hashable, Codable, Sendable, Identifiable {

    /// The SHA-1 hash. Names can repeat (for example after renewing a certificate), hashes can't.
    public let sha1: String
    public let name: String

    public var id: String { sha1 }

    public init(sha1: String, name: String) {
        self.sha1 = sha1
        self.name = name
    }

    @concurrent
    public static func available() async throws -> [SigningIdentity] {
        parse(try await XcodeCommand.signingIdentities().output())
    }

    /// Parses lines like `  1) 0123…ABCD "Apple Distribution: Company (TEAMID)"`.
    public static func parse(_ output: String) -> [SigningIdentity] {
        var seen = Set<String>()

        return output.split(separator: "\n").compactMap { line -> SigningIdentity? in
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 2)
            guard
                parts.count == 3, parts[0].hasSuffix(")"),
                parts[1].count == 40, parts[1].allSatisfy(\.isHexDigit),
                parts[2].hasPrefix("\""), parts[2].hasSuffix("\""), parts[2].count > 2,
                seen.insert(String(parts[1])).inserted
            else {
                return nil
            }

            return SigningIdentity(sha1: String(parts[1]), name: String(parts[2].dropFirst().dropLast()))
        }
    }

}
