//
//  Platform+UI.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import FrameGenKit
import Foundation

/// Display names live in the app so they can be localized; FrameGenKit only knows build facts.
extension Platform {

    var title: String {
        switch self {
        case .iOS:
            return "iOS"
        case .iOSSimulator:
            return String(localized: "iOS Simulator")
        case .macCatalyst:
            return "Mac Catalyst"
        case .macOS:
            return "macOS"
        case .tvOS:
            return "tvOS"
        case .tvOSSimulator:
            return String(localized: "tvOS Simulator")
        case .watchOS:
            return "watchOS"
        case .watchOSSimulator:
            return String(localized: "watchOS Simulator")
        case .visionOS:
            return "visionOS"
        case .visionOSSimulator:
            return String(localized: "visionOS Simulator")
        }
    }

    var detail: String {
        switch self {
        case .iOS:
            return String(localized: "iPhone and iPad devices")
        case .iOSSimulator, .tvOSSimulator, .watchOSSimulator, .visionOSSimulator:
            return String(localized: "Simulator on Apple silicon and Intel Macs")
        case .macCatalyst:
            return String(localized: "iPad apps running on the Mac")
        case .macOS:
            return String(localized: "Native Mac apps")
        case .tvOS:
            return String(localized: "Apple TV devices")
        case .watchOS:
            return String(localized: "Apple Watch devices")
        case .visionOS:
            return String(localized: "Apple Vision Pro devices")
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
        case .macOS:
            return "desktopcomputer"
        case .tvOS, .tvOSSimulator:
            return "appletv"
        case .watchOS, .watchOSSimulator:
            return "applewatch"
        case .visionOS, .visionOSSimulator:
            return "visionpro"
        }
    }

}

extension Platform.Family {

    var title: String {
        switch self {
        case .iOS:
            return "iOS"
        case .macOS:
            return "macOS"
        case .tvOS:
            return "tvOS"
        case .watchOS:
            return "watchOS"
        case .visionOS:
            return "visionOS"
        }
    }

}
