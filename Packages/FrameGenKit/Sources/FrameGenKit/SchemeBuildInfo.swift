//
//  SchemeBuildInfo.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// What the framework target of a scheme supports, from `xcodebuild -showBuildSettings -json`.
public struct SchemeBuildInfo: Equatable, Sendable {

    public let targetName: String
    public let productName: String?
    public let marketingVersion: String?
    public let supportedPlatforms: Set<Platform>

    public init(targetName: String, productName: String?, marketingVersion: String?, supportedPlatforms: Set<Platform>) {
        self.targetName = targetName
        self.productName = productName
        self.marketingVersion = marketingVersion
        self.supportedPlatforms = supportedPlatforms
    }

    @concurrent
    public static func load(_ container: ProjectContainer, scheme: String) async throws -> SchemeBuildInfo {
        let output = try await XcodeCommand.showBuildSettings(container, scheme: scheme).output()

        return try parse(Data(output.utf8), scheme: scheme)
    }

    /// Picks the framework target: the one named like the scheme, otherwise the first framework
    /// that isn't a CocoaPods dependency (CocoaPods schemes also list every `Pods-…` target).
    public static func parse(_ data: Data, scheme: String) throws -> SchemeBuildInfo {
        struct Entry: Decodable {
            let target: String
            let buildSettings: [String: String]
        }

        let entries = try JSONDecoder().decode([Entry].self, from: data)
        let frameworks = entries.filter { $0.buildSettings["PRODUCT_TYPE"] == "com.apple.product-type.framework" }
        let candidates = frameworks.isEmpty ? entries : frameworks
        guard let entry = candidates.first(where: { $0.target == scheme })
                ?? candidates.first(where: { !$0.target.hasPrefix("Pods") })
                ?? candidates.first
        else {
            throw SchemeBuildInfoError.noTargets(scheme: scheme)
        }

        let settings = entry.buildSettings
        let sdks = Set((settings["SUPPORTED_PLATFORMS"] ?? "").split(separator: " ").map(String.init))
        var platforms = Set(Platform.allCases.filter { $0.sdk.map(sdks.contains) == true })
        if sdks.contains("iphoneos"), settings["SUPPORTS_MACCATALYST"] == "YES" {
            platforms.insert(.macCatalyst)
        }

        return SchemeBuildInfo(targetName: entry.target,
                               productName: settings["PRODUCT_NAME"],
                               marketingVersion: settings["MARKETING_VERSION"].flatMap { $0.isEmpty ? nil : $0 },
                               supportedPlatforms: platforms)
    }

}

public enum SchemeBuildInfoError: LocalizedError, Equatable {
    case noTargets(scheme: String)

    public var errorDescription: String? {
        switch self {
        case .noTargets(let scheme):
            return "The scheme \(scheme) doesn't build any target."
        }
    }
}
