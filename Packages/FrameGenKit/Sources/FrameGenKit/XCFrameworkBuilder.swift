//
//  XCFrameworkBuilder.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import CryptoKit
import Foundation

public enum XCFrameworkBuilderError: Error, Equatable {
    case frameworkNotFound(archivePath: String)
    case mismatchedFrameworks(names: [String])
}

extension XCFrameworkBuilderError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .frameworkNotFound(let archivePath):
            return "No framework was found in the archive at \(archivePath). Make sure the scheme builds a framework target."
        case .mismatchedFrameworks(let names):
            return "Archives contain different frameworks: \(names.joined(separator: ", "))."
        }
    }

}

/// Turns the archives produced by `xcodebuild archive` into a distributable XCFramework.
public enum XCFrameworkBuilder {

    // MARK: - Properties

    public struct Slice: Equatable, Sendable {
        public let frameworkURL: URL
        public let debugSymbolURLs: [URL]
        
        public init(frameworkURL: URL, debugSymbolURLs: [URL]) {
            self.frameworkURL = frameworkURL
            self.debugSymbolURLs = debugSymbolURLs
        }
    }

    public struct Plan: Equatable, Sendable {
        public let frameworkName: String
        public let slices: [Slice]
        public let xcframeworkURL: URL
        public let zipURL: URL
        public let snippetURL: URL
        
        public init(frameworkName: String, slices: [Slice], xcframeworkURL: URL, zipURL: URL, snippetURL: URL) {
            self.frameworkName = frameworkName
            self.slices = slices
            self.xcframeworkURL = xcframeworkURL
            self.zipURL = zipURL
            self.snippetURL = snippetURL
        }
    }

    public struct Summary: Equatable, Sendable {
        public let plan: Plan
        public let checksum: String
        public let packageSnippet: String
        /// `nil` until a download URL is known, then the snippet uses it instead of a placeholder.
        public let downloadURL: URL?
        public let zipSize: Int64
        public let librariesWithoutPrivacyManifest: [String]
        /// The name of the certificate the XCFramework is signed with, or `nil` when unsigned.
        public let signedBy: String?
        
        public init(plan: Plan,
                    checksum: String,
                    packageSnippet: String,
                    downloadURL: URL?,
                    zipSize: Int64,
                    librariesWithoutPrivacyManifest: [String],
                    signedBy: String?) {
            self.plan = plan
            self.checksum = checksum
            self.packageSnippet = packageSnippet
            self.downloadURL = downloadURL
            self.zipSize = zipSize
            self.librariesWithoutPrivacyManifest = librariesWithoutPrivacyManifest
            self.signedBy = signedBy
        }
        
        /// Points the snippet, and the snippet file next to the zip, at the published download URL.
        public func withDownloadURL(_ url: URL) throws -> Summary {
            let snippet = XCFrameworkBuilder.packageSnippet(name: plan.frameworkName, url: url, checksum: checksum)
            try snippet.write(to: plan.snippetURL, atomically: true, encoding: .utf8)
            
            return Summary(plan: plan,
                           checksum: checksum,
                           packageSnippet: snippet,
                           downloadURL: url,
                           zipSize: zipSize,
                           librariesWithoutPrivacyManifest: librariesWithoutPrivacyManifest,
                           signedBy: signedBy)
        }
    }
    
    // MARK: - Public methods

    /// Finds the framework and its dSYM in every archive and removes stale output,
    /// because `xcodebuild -create-xcframework` refuses to overwrite an existing bundle.
    @concurrent
    public static func makePlan(archiveURLs: [URL], outputDirectoryURL: URL) async throws -> Plan {
        let fileManager = FileManager.default
        var slices: [Slice] = []
        var names: [String] = []
        for archiveURL in archiveURLs {
            let frameworksURL = archiveURL.appendingPathComponent("Products/Library/Frameworks", isDirectory: true)
            let contents = (try? fileManager.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil)) ?? []
            guard let frameworkURL = contents.first(where: { $0.pathExtension == "framework" }) else {
                throw XCFrameworkBuilderError.frameworkNotFound(archivePath: archiveURL.path)
            }

            let dSYMURL = archiveURL
                .appendingPathComponent("dSYMs", isDirectory: true)
                .appendingPathComponent(frameworkURL.lastPathComponent + ".dSYM", isDirectory: true)
            let debugSymbolURLs = fileManager.fileExists(atPath: dSYMURL.path) ? [dSYMURL] : []
            slices.append(Slice(frameworkURL: frameworkURL, debugSymbolURLs: debugSymbolURLs))
            names.append(frameworkURL.deletingPathExtension().lastPathComponent)
        }

        let uniqueNames = Array(Set(names)).sorted()
        guard uniqueNames.count == 1, let frameworkName = uniqueNames.first else {
            throw XCFrameworkBuilderError.mismatchedFrameworks(names: uniqueNames)
        }

        let xcframeworkURL = outputDirectoryURL.appendingPathComponent(frameworkName + ".xcframework", isDirectory: true)
        let zipURL = outputDirectoryURL.appendingPathComponent(frameworkName + ".xcframework.zip")
        let snippetURL = outputDirectoryURL.appendingPathComponent(frameworkName + ".binaryTarget.txt")
        for url in [xcframeworkURL, zipURL, snippetURL] where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }

        return Plan(frameworkName: frameworkName,
                    slices: slices,
                    xcframeworkURL: xcframeworkURL,
                    zipURL: zipURL,
                    snippetURL: snippetURL)
    }

    /// Computes the SwiftPM checksum of the zip, checks privacy manifests and writes the `binaryTarget` snippet.
    @concurrent
    public static func finalize(_ plan: Plan, downloadURL: URL? = nil, signedBy: String? = nil) async throws -> Summary {
        let checksum = try checksum(of: plan.zipURL)
        let snippet = packageSnippet(name: plan.frameworkName, url: downloadURL, checksum: checksum, zipName: plan.zipURL.lastPathComponent)
        try snippet.write(to: plan.snippetURL, atomically: true, encoding: .utf8)
        let zipSize = (try? plan.zipURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? .zero

        return Summary(plan: plan,
                       checksum: checksum,
                       packageSnippet: snippet,
                       downloadURL: downloadURL,
                       zipSize: zipSize,
                       librariesWithoutPrivacyManifest: librariesWithoutPrivacyManifest(in: plan.xcframeworkURL),
                       signedBy: signedBy)
    }

    /// The `.binaryTarget` declaration for Package.swift. Without a URL it points to a placeholder to replace.
    public static func packageSnippet(name: String, url: URL?, checksum: String, zipName: String? = nil) -> String {
        let location = url?.absoluteString ?? "https://example.com/\(zipName ?? name + ".xcframework.zip")"

        return """
        .binaryTarget(
            name: "\(name)",
            url: "\(location)",
            checksum: "\(checksum)"
        )

        """
    }

    // MARK: - Private methods

    /// SwiftPM's checksum is the SHA-256 of the archive, the same value `swift package compute-checksum` prints.
    private static func checksum(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)

        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Returns the library identifiers (e.g. `ios-arm64`) whose framework has no `PrivacyInfo.xcprivacy`.
    private static func librariesWithoutPrivacyManifest(in xcframeworkURL: URL) -> [String] {
        let fileManager = FileManager.default
        let libraries = (try? fileManager.contentsOfDirectory(at: xcframeworkURL,
                                                              includingPropertiesForKeys: [.isDirectoryKey],
                                                              options: .skipsHiddenFiles)) ?? []

        return libraries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { libraryURL in
                let frameworks = (try? fileManager.contentsOfDirectory(at: libraryURL, includingPropertiesForKeys: nil)) ?? []

                return frameworks
                    .filter { $0.pathExtension == "framework" }
                    .contains { frameworkURL in
                        // iOS frameworks are flat, macOS and Mac Catalyst ones keep resources under Versions/A.
                        let candidates = ["PrivacyInfo.xcprivacy", "Versions/A/Resources/PrivacyInfo.xcprivacy"]

                        return !candidates.contains { fileManager.fileExists(atPath: frameworkURL.appendingPathComponent($0).path) }
                    }
            }
            .map(\.lastPathComponent)
            .sorted()
    }

}
