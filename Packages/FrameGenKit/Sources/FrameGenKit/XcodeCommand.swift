//
//  XcodeCommand.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// Builds the command lines FrameGen runs. Arguments are passed as an array,
/// so paths with spaces or quotes never need escaping.
public enum XcodeCommand {

    private static let xcodebuildURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    private static let dittoURL = URL(fileURLWithPath: "/usr/bin/ditto")
    private static let codesignURL = URL(fileURLWithPath: "/usr/bin/codesign")
    private static let securityURL = URL(fileURLWithPath: "/usr/bin/security")

    public static func list(_ container: ProjectContainer) -> ProcessRunner {
        ProcessRunner(executableURL: xcodebuildURL,
                      arguments: ["-list", "-json"] + container.xcodebuildArguments,
                      mergesStandardError: false)
    }

    public static func showBuildSettings(_ container: ProjectContainer, scheme: String) -> ProcessRunner {
        ProcessRunner(executableURL: xcodebuildURL,
                      arguments: ["-showBuildSettings", "-json", "-scheme", scheme] + container.xcodebuildArguments,
                      mergesStandardError: false)
    }

    public static func archive(_ container: ProjectContainer,
                               scheme: String,
                               configuration: String,
                               platform: Platform,
                               archiveURL: URL) -> ProcessRunner {
        ProcessRunner(executableURL: xcodebuildURL,
                      arguments: ["archive"]
                        + container.xcodebuildArguments
                        + ["-scheme", scheme,
                           "-configuration", configuration,
                           "-destination", platform.destination,
                           "-archivePath", archiveURL.path,
                           "SKIP_INSTALL=NO",
                           "BUILD_LIBRARIES_FOR_DISTRIBUTION=YES",
                           // Recent Xcode versions no longer derive these from BUILD_LIBRARIES_FOR_DISTRIBUTION,
                           // and -create-xcframework refuses Swift frameworks without a .swiftinterface.
                           "SWIFT_ENABLE_LIBRARY_EVOLUTION=YES",
                           "SWIFT_EMIT_MODULE_INTERFACE=YES"])
    }

    public static func createXCFramework(slices: [XCFrameworkBuilder.Slice], output: URL) -> ProcessRunner {
        let sliceArguments = slices.flatMap { slice in
            ["-framework", slice.frameworkURL.path] + slice.debugSymbolURLs.flatMap { ["-debug-symbols", $0.path] }
        }

        return ProcessRunner(executableURL: xcodebuildURL,
                             arguments: ["-create-xcframework"] + sliceArguments + ["-output", output.path])
    }

    /// Signs the XCFramework with a secure timestamp. `identity` is a SHA-1 hash or a certificate name.
    public static func sign(_ url: URL, identity: String) -> ProcessRunner {
        ProcessRunner(executableURL: codesignURL,
                      arguments: ["--timestamp", "--force", "--sign", identity, url.path])
    }

    public static func verifySignature(_ url: URL) -> ProcessRunner {
        ProcessRunner(executableURL: codesignURL,
                      arguments: ["--verify", "--strict", "--verbose=2", url.path])
    }

    public static func signingIdentities() -> ProcessRunner {
        ProcessRunner(executableURL: securityURL,
                      arguments: ["find-identity", "-v", "-p", "codesigning"],
                      mergesStandardError: false)
    }

    public static func zip(source: URL, destination: URL) -> ProcessRunner {
        ProcessRunner(executableURL: dittoURL,
                      arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, destination.path])
    }

}
