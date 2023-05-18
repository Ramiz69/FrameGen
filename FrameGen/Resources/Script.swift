//
//  Script.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//

import Foundation

enum Script {
    case iPhoneOS
    case simulatorOS
    case macCatalyst
    
    var destination: String {
        switch self {
        case .iPhoneOS:
            return "generic/platform=iOS"
        case .simulatorOS:
            return "generic/platform=iOS Simulator"
        case .macCatalyst:
            return "platform=macOS,arch=x86_64,variant=Mac Catalyst"
        }
    }
    
    var archiveName: String {
        switch self {
        case .iPhoneOS:
            return ".framework-iphoneos.xcarchive"
        case .simulatorOS:
            return ".framework-iphonesimulator.xcarchive"
        case .macCatalyst:
            return ".framework-catalyst.xcarchive"
        }
    }
}
