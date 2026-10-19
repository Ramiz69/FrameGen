//
//  Platform.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// A platform slice of the XCFramework, built by its own `xcodebuild archive` run.
nonisolated enum Platform: String, CaseIterable, Codable, Identifiable, Sendable {
    case iOS
    case iOSSimulator
    case macCatalyst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iOS:
            return "iOS"
        case .iOSSimulator:
            return "iOS Simulator"
        case .macCatalyst:
            return "Mac Catalyst"
        }
    }

    var detail: String {
        switch self {
        case .iOS:
            return "iPhone and iPad devices, arm64"
        case .iOSSimulator:
            return "Simulator on Apple silicon and Intel Macs"
        case .macCatalyst:
            return "iPad apps running on the Mac"
        }
    }

    var systemImage: String {
        switch self {
        case .iOS:
            return "iphone"
        case .iOSSimulator:
            return "macbook.and.iphone"
        case .macCatalyst:
            return "macwindow"
        }
    }

    var destination: String {
        switch self {
        case .iOS:
            return "generic/platform=iOS"
        case .iOSSimulator:
            return "generic/platform=iOS Simulator"
        case .macCatalyst:
            return "generic/platform=macOS,variant=Mac Catalyst"
        }
    }

    var archiveSuffix: String {
        switch self {
        case .iOS:
            return "iphoneos"
        case .iOSSimulator:
            return "iphonesimulator"
        case .macCatalyst:
            return "maccatalyst"
        }
    }
}
