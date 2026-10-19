//
//  ProjectContainer.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// The `.xcodeproj` or `.xcworkspace` that xcodebuild builds.
public struct ProjectContainer: Hashable, Codable, Sendable {

    public enum Kind: String, Codable, Sendable {
        case project
        case workspace
    }

    public let url: URL
    public let kind: Kind

    /// Returns `nil` for anything other than an `.xcodeproj` or `.xcworkspace`.
    public init?(url: URL) {
        switch url.pathExtension {
        case "xcodeproj":
            kind = .project
        case "xcworkspace":
            kind = .workspace
        default:
            return nil
        }
        self.url = url
    }

    public var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    public var directoryURL: URL {
        url.deletingLastPathComponent()
    }

    /// `-project <path>` or `-workspace <path>`.
    public var xcodebuildArguments: [String] {
        [kind == .project ? "-project" : "-workspace", url.path]
    }

}
