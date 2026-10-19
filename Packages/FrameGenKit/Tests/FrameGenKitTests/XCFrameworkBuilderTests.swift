//
//  XCFrameworkBuilderTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Testing
import Foundation
import CryptoKit
@testable import FrameGenKit

@Suite struct XCFrameworkBuilderTests {

    // MARK: - Helpers

    /// Creates `<tmp>/Archives/<archiveName>.xcarchive` with a framework and, optionally, its dSYM.
    @discardableResult
    private func makeArchive(_ archiveName: String,
                             framework: String? = "Kit",
                             includesDebugSymbols: Bool = true,
                             in directory: TemporaryDirectory) throws -> URL {
        let archivePath = "Archives/\(archiveName).xcarchive"
        let archiveURL = try directory.makeDirectory(archivePath)
        try directory.makeDirectory("\(archivePath)/Products/Library/Frameworks")
        if let framework {
            try directory.makeDirectory("\(archivePath)/Products/Library/Frameworks/\(framework).framework")
            if includesDebugSymbols {
                try directory.makeDirectory("\(archivePath)/dSYMs/\(framework).framework.dSYM")
            }
        }

        return archiveURL
    }

    // MARK: - makePlan

    @Test("makePlan finds the framework, its dSYM and the output locations")
    func planForSingleArchive() async throws {
        let directory = try TemporaryDirectory()
        let archiveURL = try makeArchive("Kit-iphoneos", in: directory)
        let outputURL = try directory.makeDirectory("Output")

        let plan = try await XCFrameworkBuilder.makePlan(archiveURLs: [archiveURL], outputDirectoryURL: outputURL)

        #expect(plan.frameworkName == "Kit")
        let slice = try #require(plan.slices.first)
        #expect(plan.slices.count == 1)
        let expectedFramework = archiveURL.appendingPathComponent("Products/Library/Frameworks/Kit.framework")
        #expect(slice.frameworkURL.path == expectedFramework.path)
        let expectedDebugSymbols = archiveURL.appendingPathComponent("dSYMs/Kit.framework.dSYM")
        #expect(slice.debugSymbolURLs.map(\.path) == [expectedDebugSymbols.path])
        #expect(plan.xcframeworkURL.path == outputURL.appendingPathComponent("Kit.xcframework").path)
        #expect(plan.zipURL.path == outputURL.appendingPathComponent("Kit.xcframework.zip").path)
        #expect(plan.snippetURL.path == outputURL.appendingPathComponent("Kit.binaryTarget.txt").path)
    }

    @Test("makePlan leaves debug symbols empty when the archive has no dSYM")
    func planWithoutDebugSymbols() async throws {
        let directory = try TemporaryDirectory()
        let archiveURL = try makeArchive("Kit-iphoneos", includesDebugSymbols: false, in: directory)
        let outputURL = try directory.makeDirectory("Output")

        let plan = try await XCFrameworkBuilder.makePlan(archiveURLs: [archiveURL], outputDirectoryURL: outputURL)

        let slice = try #require(plan.slices.first)
        #expect(slice.debugSymbolURLs.isEmpty)
    }

    @Test("makePlan returns slices in archive order")
    func planKeepsArchiveOrder() async throws {
        let directory = try TemporaryDirectory()
        let simulatorURL = try makeArchive("Kit-iphonesimulator", in: directory)
        let deviceURL = try makeArchive("Kit-iphoneos", in: directory)
        let outputURL = try directory.makeDirectory("Output")

        let plan = try await XCFrameworkBuilder.makePlan(archiveURLs: [simulatorURL, deviceURL],
                                                         outputDirectoryURL: outputURL)

        #expect(plan.slices.count == 2)
        let frameworkPaths = plan.slices.map(\.frameworkURL.path)
        let expectedPaths = [simulatorURL, deviceURL].map {
            $0.appendingPathComponent("Products/Library/Frameworks/Kit.framework").path
        }
        #expect(frameworkPaths == expectedPaths)
    }

    @Test("makePlan throws frameworkNotFound when an archive has no framework")
    func planThrowsWhenFrameworkIsMissing() async throws {
        let directory = try TemporaryDirectory()
        let archiveURL = try makeArchive("Empty-iphoneos", framework: nil, in: directory)
        let outputURL = try directory.makeDirectory("Output")

        await #expect {
            _ = try await XCFrameworkBuilder.makePlan(archiveURLs: [archiveURL], outputDirectoryURL: outputURL)
        } throws: { error in
            guard case let XCFrameworkBuilderError.frameworkNotFound(archivePath) = error else {
                return false
            }

            return archivePath == archiveURL.path
        }
    }

    @Test("makePlan throws mismatchedFrameworks when archives contain different frameworks")
    func planThrowsForMismatchedFrameworks() async throws {
        let directory = try TemporaryDirectory()
        let kitURL = try makeArchive("Kit-iphoneos", framework: "Kit", in: directory)
        let otherURL = try makeArchive("Other-iphonesimulator", framework: "Other", in: directory)
        let outputURL = try directory.makeDirectory("Output")

        await #expect {
            _ = try await XCFrameworkBuilder.makePlan(archiveURLs: [kitURL, otherURL], outputDirectoryURL: outputURL)
        } throws: { error in
            guard case let XCFrameworkBuilderError.mismatchedFrameworks(names) = error else {
                return false
            }

            return names == ["Kit", "Other"]
        }
    }

    @Test("makePlan removes stale output from a previous run")
    func planRemovesStaleOutput() async throws {
        let directory = try TemporaryDirectory()
        let archiveURL = try makeArchive("Kit-iphoneos", in: directory)
        let outputURL = try directory.makeDirectory("Output")
        try directory.makeFile("Output/Kit.xcframework/Info.plist", contents: Data("old".utf8))
        try directory.makeFile("Output/Kit.xcframework.zip", contents: Data("old".utf8))
        try directory.makeFile("Output/Kit.binaryTarget.txt", contents: Data("old".utf8))

        let plan = try await XCFrameworkBuilder.makePlan(archiveURLs: [archiveURL], outputDirectoryURL: outputURL)

        let fileManager = FileManager.default
        #expect(!fileManager.fileExists(atPath: plan.xcframeworkURL.path))
        #expect(!fileManager.fileExists(atPath: plan.zipURL.path))
        #expect(!fileManager.fileExists(atPath: plan.snippetURL.path))
        #expect(fileManager.fileExists(atPath: outputURL.path))
    }

    // MARK: - finalize

    @Test("finalize computes the checksum, finds missing privacy manifests and writes the snippet")
    func finalizeSummarizesTheOutput() async throws {
        let directory = try TemporaryDirectory()
        let archiveURL = try makeArchive("Kit-iphoneos", in: directory)
        let outputURL = try directory.makeDirectory("Output")
        let plan = try await XCFrameworkBuilder.makePlan(archiveURLs: [archiveURL], outputDirectoryURL: outputURL)

        let xcframework = "Output/Kit.xcframework"
        try directory.makeFile("\(xcframework)/ios-arm64/Kit.framework/PrivacyInfo.xcprivacy")
        try directory.makeFile("\(xcframework)/ios-arm64_x86_64-maccatalyst/Kit.framework/Versions/A/Resources/PrivacyInfo.xcprivacy")
        try directory.makeDirectory("\(xcframework)/ios-arm64_x86_64-simulator/Kit.framework")
        try directory.makeFile("\(xcframework)/Info.plist", contents: Data("plist".utf8))
        let zipBytes = Data("FrameGen fake zip contents".utf8)
        try zipBytes.write(to: plan.zipURL)
        let expectedChecksum = SHA256.hash(data: zipBytes).map { String(format: "%02x", $0) }.joined()

        let summary = try await XCFrameworkBuilder.finalize(plan)

        #expect(summary.checksum == expectedChecksum)
        #expect(summary.zipSize == Int64(zipBytes.count))
        #expect(summary.librariesWithoutPrivacyManifest == ["ios-arm64_x86_64-simulator"])
        #expect(summary.packageSnippet.contains(#"name: "Kit""#))
        #expect(summary.packageSnippet.contains("Kit.xcframework.zip"))
        #expect(summary.packageSnippet.contains(expectedChecksum))
        let writtenSnippet = try String(contentsOf: plan.snippetURL, encoding: .utf8)
        #expect(writtenSnippet == summary.packageSnippet)
        #expect(summary.packageSnippet.contains("https://example.com/Kit.xcframework.zip"))
        #expect(summary.downloadURL == nil)
        #expect(summary.signedBy == nil)
    }

    /// Plans a build for `Kit` with a fake zip, ready for `finalize`.
    private func makeFinalizablePlan(in directory: TemporaryDirectory,
                                     zipBytes: Data = Data("zip".utf8)) async throws -> XCFrameworkBuilder.Plan {
        let archiveURL = try makeArchive("Kit-iphoneos", in: directory)
        let outputURL = try directory.makeDirectory("Output")
        let plan = try await XCFrameworkBuilder.makePlan(archiveURLs: [archiveURL], outputDirectoryURL: outputURL)
        try directory.makeDirectory("Output/Kit.xcframework/ios-arm64/Kit.framework")
        try directory.makeFile("Output/Kit.xcframework/ios-arm64/Kit.framework/PrivacyInfo.xcprivacy")
        try zipBytes.write(to: plan.zipURL)

        return plan
    }

    @Test("finalize puts the download URL and the signer into the summary and the snippet")
    func finalizeWithDownloadURL() async throws {
        let directory = try TemporaryDirectory()
        let plan = try await makeFinalizablePlan(in: directory)
        let downloadURL = try #require(URL(string: "https://cdn.example.org/Kit/1.2.0/Kit.xcframework.zip"))

        let summary = try await XCFrameworkBuilder.finalize(plan, downloadURL: downloadURL, signedBy: "Apple Distribution: Company (TEAMID)")

        #expect(summary.downloadURL == downloadURL)
        #expect(summary.signedBy == "Apple Distribution: Company (TEAMID)")
        #expect(summary.librariesWithoutPrivacyManifest.isEmpty)
        #expect(summary.packageSnippet.contains(#"url: "https://cdn.example.org/Kit/1.2.0/Kit.xcframework.zip""#))
        #expect(!summary.packageSnippet.contains("example.com"))
        #expect(summary.packageSnippet == XCFrameworkBuilder.packageSnippet(name: "Kit", url: downloadURL, checksum: summary.checksum))
        #expect(try String(contentsOf: plan.snippetURL, encoding: .utf8) == summary.packageSnippet)
    }

    @Test("withDownloadURL rewrites the snippet file and keeps everything else")
    func withDownloadURL() async throws {
        let directory = try TemporaryDirectory()
        let plan = try await makeFinalizablePlan(in: directory)
        let summary = try await XCFrameworkBuilder.finalize(plan, signedBy: "Developer ID Application: Me (TEAMID)")
        let downloadURL = try #require(URL(string: "https://github.com/o/r/releases/download/v1.0/Kit.xcframework.zip"))

        let updated = try summary.withDownloadURL(downloadURL)

        #expect(updated.downloadURL == downloadURL)
        #expect(updated.packageSnippet.contains(#"url: "https://github.com/o/r/releases/download/v1.0/Kit.xcframework.zip""#))
        #expect(!updated.packageSnippet.contains("example.com"))
        #expect(updated.plan == summary.plan)
        #expect(updated.checksum == summary.checksum)
        #expect(updated.zipSize == summary.zipSize)
        #expect(updated.signedBy == summary.signedBy)
        #expect(updated.librariesWithoutPrivacyManifest == summary.librariesWithoutPrivacyManifest)
        #expect(try String(contentsOf: plan.snippetURL, encoding: .utf8) == updated.packageSnippet)
        // The original value is unchanged.
        #expect(summary.downloadURL == nil)
        #expect(summary.packageSnippet.contains("https://example.com/Kit.xcframework.zip"))
    }

    // MARK: - packageSnippet

    @Test("packageSnippet without a URL points to a placeholder named after the zip")
    func snippetPlaceholder() {
        let snippet = XCFrameworkBuilder.packageSnippet(name: "Kit", url: nil, checksum: "abc123", zipName: "Kit-1.0.xcframework.zip")

        #expect(snippet == """
        .binaryTarget(
            name: "Kit",
            url: "https://example.com/Kit-1.0.xcframework.zip",
            checksum: "abc123"
        )

        """)
    }

    @Test("packageSnippet without a URL or zip name derives the zip from the framework name")
    func snippetDefaultPlaceholder() {
        let snippet = XCFrameworkBuilder.packageSnippet(name: "Kit", url: nil, checksum: "abc123")

        #expect(snippet.contains(#"url: "https://example.com/Kit.xcframework.zip""#))
    }

    @Test("packageSnippet uses the URL instead of the placeholder when given")
    func snippetWithURL() throws {
        let url = try #require(URL(string: "https://cdn.example.org/Kit.zip"))
        let snippet = XCFrameworkBuilder.packageSnippet(name: "Kit", url: url, checksum: "abc123", zipName: "Ignored.zip")

        #expect(snippet == """
        .binaryTarget(
            name: "Kit",
            url: "https://cdn.example.org/Kit.zip",
            checksum: "abc123"
        )

        """)
    }

}
