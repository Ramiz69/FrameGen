//
//  SchemeBuildInfoTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("Reading xcodebuild -showBuildSettings -json")
struct SchemeBuildInfoTests {

    private func parse(_ json: String, scheme: String) throws -> SchemeBuildInfo {
        try SchemeBuildInfo.parse(Data(json.utf8), scheme: scheme)
    }

    // MARK: - Samples

    /// A plain multiplatform framework project, trimmed to the settings FrameGen reads plus some noise.
    private let multiplatformFramework = """
    [
      {
        "action" : "build",
        "buildSettings" : {
          "ACTION" : "build",
          "ARCHS" : "arm64",
          "CONFIGURATION" : "Release",
          "MACH_O_TYPE" : "mh_dylib",
          "MARKETING_VERSION" : "2.4.1",
          "PRODUCT_BUNDLE_IDENTIFIER" : "com.example.Kit",
          "PRODUCT_NAME" : "Kit",
          "PRODUCT_TYPE" : "com.apple.product-type.framework",
          "SDKROOT" : "iphoneos",
          "SUPPORTED_PLATFORMS" : "appletvos appletvsimulator iphoneos iphonesimulator macosx watchos watchsimulator xros xrsimulator",
          "SUPPORTS_MACCATALYST" : "YES",
          "TARGET_NAME" : "Kit"
        },
        "target" : "Kit"
      },
      {
        "action" : "build",
        "buildSettings" : {
          "PRODUCT_NAME" : "KitTests",
          "PRODUCT_TYPE" : "com.apple.product-type.bundle.unit-test",
          "SUPPORTED_PLATFORMS" : "iphoneos iphonesimulator",
          "TARGET_NAME" : "KitTests"
        },
        "target" : "KitTests"
      }
    ]
    """

    /// A CocoaPods workspace scheme: the `Pods-…` aggregate and pod targets come first, and the
    /// framework is a static framework with a product name that differs from the scheme.
    private let cocoaPodsWorkspace = """
    [
      {
        "action" : "build",
        "buildSettings" : {
          "MACH_O_TYPE" : "staticlib",
          "PRODUCT_NAME" : "Alamofire",
          "PRODUCT_TYPE" : "com.apple.product-type.framework",
          "SUPPORTED_PLATFORMS" : "iphoneos iphonesimulator macosx",
          "TARGET_NAME" : "Alamofire"
        },
        "target" : "Alamofire"
      },
      {
        "action" : "build",
        "buildSettings" : {
          "MACH_O_TYPE" : "staticlib",
          "PRODUCT_NAME" : "Pods_PaymentsSDK",
          "PRODUCT_TYPE" : "com.apple.product-type.framework",
          "SUPPORTED_PLATFORMS" : "iphoneos iphonesimulator",
          "TARGET_NAME" : "Pods-PaymentsSDK"
        },
        "target" : "Pods-PaymentsSDK"
      },
      {
        "action" : "build",
        "buildSettings" : {
          "MACH_O_TYPE" : "staticlib",
          "MARKETING_VERSION" : "",
          "PRODUCT_NAME" : "Payments",
          "PRODUCT_TYPE" : "com.apple.product-type.framework",
          "SUPPORTED_PLATFORMS" : "iphonesimulator iphoneos",
          "SUPPORTS_MACCATALYST" : "NO",
          "TARGET_NAME" : "PaymentsSDK"
        },
        "target" : "PaymentsSDK"
      }
    ]
    """

    // MARK: - Tests

    @Test("Reads the framework named like the scheme with every supported platform")
    func multiplatform() throws {
        let info = try parse(multiplatformFramework, scheme: "Kit")

        #expect(info.targetName == "Kit")
        #expect(info.productName == "Kit")
        #expect(info.marketingVersion == "2.4.1")
        #expect(info.supportedPlatforms == Set(Platform.allCases))
    }

    @Test("Picks the scheme's framework over Pods targets in a CocoaPods workspace")
    func cocoaPodsSchemeTarget() throws {
        let info = try parse(cocoaPodsWorkspace, scheme: "PaymentsSDK")

        #expect(info.targetName == "PaymentsSDK")
        #expect(info.productName == "Payments")
        #expect(info.marketingVersion == nil)
        #expect(info.supportedPlatforms == [.iOS, .iOSSimulator])
    }

    @Test("Without a target named like the scheme, the first framework not prefixed Pods wins")
    func firstNonPodsFramework() throws {
        let json = """
        [
          { "target" : "Pods-App", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.framework", "SUPPORTED_PLATFORMS" : "iphoneos" } },
          { "target" : "App", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.application", "SUPPORTED_PLATFORMS" : "iphoneos" } },
          { "target" : "CoreKit", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.framework", "SUPPORTED_PLATFORMS" : "macosx", "PRODUCT_NAME" : "CoreKit" } },
          { "target" : "UIKitExtras", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.framework", "SUPPORTED_PLATFORMS" : "iphoneos" } }
        ]
        """

        let info = try parse(json, scheme: "Release Build")

        #expect(info.targetName == "CoreKit")
        #expect(info.productName == "CoreKit")
        #expect(info.supportedPlatforms == [.macOS])
    }

    @Test("In the CocoaPods sample, an unknown scheme still skips the pod aggregate")
    func cocoaPodsUnknownScheme() throws {
        let info = try parse(cocoaPodsWorkspace, scheme: "Other")

        // Alamofire is first and isn't prefixed "Pods", so it is the best guess.
        #expect(info.targetName == "Alamofire")
    }

    @Test("Only Pods frameworks: falls back to the first one")
    func onlyPodsFrameworks() throws {
        let json = """
        [
          { "target" : "Pods-A", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.framework", "SUPPORTED_PLATFORMS" : "iphoneos" } },
          { "target" : "Pods-B", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.framework", "SUPPORTED_PLATFORMS" : "macosx" } }
        ]
        """

        #expect(try parse(json, scheme: "X").targetName == "Pods-A")
    }

    @Test("Without any framework target, the scheme's target or the first target is used")
    func noFrameworks() throws {
        let json = """
        [
          { "target" : "Tool", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.tool", "SUPPORTED_PLATFORMS" : "macosx" } },
          { "target" : "App", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.application", "SUPPORTED_PLATFORMS" : "iphoneos iphonesimulator" } }
        ]
        """

        #expect(try parse(json, scheme: "App").targetName == "App")
        #expect(try parse(json, scheme: "Other").targetName == "Tool")
    }

    @Test("Mac Catalyst needs iphoneos and SUPPORTS_MACCATALYST=YES", arguments: [
        ("iphoneos iphonesimulator", "YES", true),
        ("iphoneos", "YES", true),
        ("iphoneos iphonesimulator", "NO", false),
        ("iphoneos iphonesimulator", "", false),
        ("iphonesimulator macosx", "YES", false),
        ("macosx", "YES", false),
    ])
    func macCatalyst(platforms: String, supportsCatalyst: String, expected: Bool) throws {
        let json = """
        [ { "target" : "Kit", "buildSettings" : {
            "PRODUCT_TYPE" : "com.apple.product-type.framework",
            "SUPPORTED_PLATFORMS" : "\(platforms)",
            "SUPPORTS_MACCATALYST" : "\(supportsCatalyst)" } } ]
        """

        let info = try parse(json, scheme: "Kit")

        #expect(info.supportedPlatforms.contains(.macCatalyst) == expected)
    }

    @Test("Missing SUPPORTED_PLATFORMS and unknown SDKs give no platforms")
    func noKnownPlatforms() throws {
        let missing = #"[ { "target" : "Kit", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.framework" } } ]"#
        let unknown = #"[ { "target" : "Kit", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.framework", "SUPPORTED_PLATFORMS" : "driverkit linux" } } ]"#

        #expect(try parse(missing, scheme: "Kit").supportedPlatforms.isEmpty)
        #expect(try parse(unknown, scheme: "Kit").supportedPlatforms.isEmpty)
    }

    @Test("Missing PRODUCT_NAME and MARKETING_VERSION are nil")
    func missingNames() throws {
        let json = #"[ { "target" : "Kit", "buildSettings" : { "PRODUCT_TYPE" : "com.apple.product-type.framework", "SUPPORTED_PLATFORMS" : "macosx" } } ]"#

        let info = try parse(json, scheme: "Kit")

        #expect(info.productName == nil)
        #expect(info.marketingVersion == nil)
    }

    @Test("An empty array throws noTargets with the scheme")
    func emptyThrows() {
        #expect(throws: SchemeBuildInfoError.noTargets(scheme: "Kit")) {
            try parse("[]", scheme: "Kit")
        }
    }

    @Test("Output that isn't the expected JSON throws a decoding error", arguments: ["", "{}", #"[ { "target" : "Kit" } ]"#])
    func invalidJSON(json: String) {
        #expect(throws: DecodingError.self) {
            try parse(json, scheme: "Kit")
        }
    }

    @Test("noTargets explains which scheme is empty")
    func errorDescription() {
        #expect(SchemeBuildInfoError.noTargets(scheme: "Kit").errorDescription?.contains("Kit") == true)
    }

}
