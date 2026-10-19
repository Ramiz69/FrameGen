//
//  Platform.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// A platform slice of the XCFramework, built by its own `xcodebuild archive` run.
/// Raw values are persisted in user settings, so existing cases must keep theirs.
public enum Platform: String, CaseIterable, Codable, Identifiable, Sendable {
    case iOS
    case iOSSimulator
    case macCatalyst
    case macOS
    case tvOS
    case tvOSSimulator
    case watchOS
    case watchOSSimulator
    case visionOS
    case visionOSSimulator

    /// Groups device and simulator slices of the same operating system.
    public enum Family: String, CaseIterable, Sendable {
        case iOS, macOS, tvOS, watchOS, visionOS
    }

    public var id: String { rawValue }

    public var family: Family {
        switch self {
        case .iOS, .iOSSimulator, .macCatalyst:
            return .iOS
        case .macOS:
            return .macOS
        case .tvOS, .tvOSSimulator:
            return .tvOS
        case .watchOS, .watchOSSimulator:
            return .watchOS
        case .visionOS, .visionOSSimulator:
            return .visionOS
        }
    }

    public var destination: String {
        switch self {
        case .iOS:
            return "generic/platform=iOS"
        case .iOSSimulator:
            return "generic/platform=iOS Simulator"
        case .macCatalyst:
            return "generic/platform=macOS,variant=Mac Catalyst"
        case .macOS:
            return "generic/platform=macOS"
        case .tvOS:
            return "generic/platform=tvOS"
        case .tvOSSimulator:
            return "generic/platform=tvOS Simulator"
        case .watchOS:
            return "generic/platform=watchOS"
        case .watchOSSimulator:
            return "generic/platform=watchOS Simulator"
        case .visionOS:
            return "generic/platform=visionOS"
        case .visionOSSimulator:
            return "generic/platform=visionOS Simulator"
        }
    }

    public var archiveSuffix: String {
        sdk ?? "maccatalyst"
    }

    /// The SDK name as it appears in the `SUPPORTED_PLATFORMS` build setting.
    /// Mac Catalyst has none: it is enabled by `SUPPORTS_MACCATALYST` on top of `iphoneos`.
    public var sdk: String? {
        switch self {
        case .iOS:
            return "iphoneos"
        case .iOSSimulator:
            return "iphonesimulator"
        case .macCatalyst:
            return nil
        case .macOS:
            return "macosx"
        case .tvOS:
            return "appletvos"
        case .tvOSSimulator:
            return "appletvsimulator"
        case .watchOS:
            return "watchos"
        case .watchOSSimulator:
            return "watchsimulator"
        case .visionOS:
            return "xros"
        case .visionOSSimulator:
            return "xrsimulator"
        }
    }

    /// The name used by the `framegen --platform` option.
    public var cliName: String {
        switch self {
        case .iOS:
            return "ios"
        case .iOSSimulator:
            return "ios-simulator"
        case .macCatalyst:
            return "maccatalyst"
        case .macOS:
            return "macos"
        case .tvOS:
            return "tvos"
        case .tvOSSimulator:
            return "tvos-simulator"
        case .watchOS:
            return "watchos"
        case .watchOSSimulator:
            return "watchos-simulator"
        case .visionOS:
            return "visionos"
        case .visionOSSimulator:
            return "visionos-simulator"
        }
    }

    public init?(cliName: String) {
        guard let platform = Self.allCases.first(where: { $0.cliName == cliName.lowercased() }) else { return nil }

        self = platform
    }

}
