//
//  BuildRequest.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// Everything one XCFramework build needs. FrameGen.app fills it from the project form,
/// `framegen build` from its arguments, so both run exactly the same pipeline.
public struct BuildRequest: Equatable, Sendable {

    public var container: ProjectContainer
    public var scheme: String
    public var configuration: String
    /// Archived in this order; duplicates are ignored.
    public var platforms: [Platform]
    public var outputDirectory: URL
    /// Signs the XCFramework after creating it. `nil` leaves it unsigned.
    public var signingIdentity: SigningIdentity?
    /// Keeps the per-platform `.xcarchive` folders in `Archives` after a successful build.
    public var keepArchives: Bool
    /// The release version, used by `{version}` in URL templates and by publishers.
    public var version: String?
    /// Where the zip will be downloaded from, e.g. `https://cdn.example.com/{name}/{version}/{zip}`.
    public var downloadURLTemplate: String?

    public init(container: ProjectContainer,
                scheme: String,
                configuration: String = "Release",
                platforms: [Platform],
                outputDirectory: URL,
                signingIdentity: SigningIdentity? = nil,
                keepArchives: Bool = true,
                version: String? = nil,
                downloadURLTemplate: String? = nil) {
        self.container = container
        self.scheme = scheme
        self.configuration = configuration
        self.platforms = platforms
        self.outputDirectory = outputDirectory
        self.signingIdentity = signingIdentity
        self.keepArchives = keepArchives
        self.version = version
        self.downloadURLTemplate = downloadURLTemplate
    }

    /// The platforms in a stable order without duplicates.
    public var orderedPlatforms: [Platform] {
        Platform.allCases.filter(platforms.contains)
    }

    public var archivesDirectory: URL {
        outputDirectory.appendingPathComponent("Archives", isDirectory: true)
    }

    public func archiveURL(for platform: Platform) -> URL {
        archivesDirectory.appendingPathComponent("\(scheme)-\(platform.archiveSuffix).xcarchive")
    }

}
